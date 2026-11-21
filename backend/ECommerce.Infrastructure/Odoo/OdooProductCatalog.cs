using System.Collections.Concurrent;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using ECommerce.Application.Products;
using ECommerce.Domain.Products;
using Microsoft.Extensions.Options;

namespace ECommerce.Infrastructure.Odoo;

public sealed class OdooProductCatalog(HttpClient http, IOptions<OdooOptions> options) : IProductCatalog
{
    private readonly OdooOptions _options = options.Value;
    private static readonly ConcurrentDictionary<int, Product> ProductCache = new();
    private static DateTime _cacheExpiration = DateTime.MinValue;
    private static readonly SemaphoreSlim CacheLock = new(1, 1);

    public async Task<IReadOnlyList<Product>> GetProductsAsync(int? categoryId = null, CancellationToken cancellationToken = default)
    {
        await EnsureCacheLoadedAsync(cancellationToken);

        var all = ProductCache.Values.ToList();
        if (categoryId.HasValue && categoryId.Value > 0)
        {
            return all.Where(p => p.CategoryIds.Contains(categoryId.Value)).ToArray();
        }

        return all;
    }

    public async Task<Product?> GetProductAsync(int id, CancellationToken cancellationToken = default)
    {
        await EnsureCacheLoadedAsync(cancellationToken);

        if (!ProductCache.TryGetValue(id, out var cached)) return null;
        if (!string.IsNullOrEmpty(cached.ImageUrl)) return cached;
        var rows = await SearchReadAsync(new object[] { new object[] { "id", "=", id } }, includeImage: true, cancellationToken);
        if (rows.Count == 0) return cached;
        var detailedProduct = Map(rows[0]);
        ProductCache[id] = detailedProduct;
        return detailedProduct;
    }

    public async Task<Product?> GetProductForOrderAsync(int id, CancellationToken cancellationToken = default)
    {
        await EnsureCacheLoadedAsync(cancellationToken);
        return ProductCache.TryGetValue(id, out var product) ? product : null;
    }

    private async Task EnsureCacheLoadedAsync(CancellationToken cancellationToken)
    {
        if (DateTime.UtcNow < _cacheExpiration && !ProductCache.IsEmpty)
            return;

        await CacheLock.WaitAsync(cancellationToken);
        try
        {
            if (DateTime.UtcNow < _cacheExpiration && !ProductCache.IsEmpty)
                return;

            var criteria = new List<object>
            {
                new object[] { "active", "=", true },
                new object[] { "sale_ok", "=", true }
            };

            var rows = await SearchReadAsync(criteria.ToArray(), includeImage: true, cancellationToken);
            ProductCache.Clear();
            foreach (var row in rows)
            {
                var p = Map(row);
                ProductCache[p.Id] = p;
            }

            _cacheExpiration = DateTime.UtcNow.AddMinutes(2);
        }
        finally
        {
            CacheLock.Release();
        }
    }

    private async Task<List<JsonElement>> SearchReadAsync(object? domain, bool includeImage, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(_options.ApiKey) || string.IsNullOrWhiteSpace(_options.Database))
            throw new InvalidOperationException("Falta configurar Odoo:Database y Odoo:ApiKey (usar variables de entorno o secretos de usuario).");

        using var request = new HttpRequestMessage(HttpMethod.Post, "/json/2/product.product/search_read");
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _options.ApiKey);
        request.Headers.Add("X-Odoo-Database", _options.Database);
        request.Content = JsonContent.Create(new
        {
            domain,
            fields = includeImage
                ? new[] { "id", "name", "description_sale", "list_price", "image_1920", "image_512", "image_256", "image_128", "categ_id", "active", "sale_ok", "free_qty", "is_storable" }
                : new[] { "id", "name", "description_sale", "list_price", "categ_id", "active", "sale_ok", "free_qty", "is_storable" },
            limit = 1000,
        });

        using var response = await http.SendAsync(request, cancellationToken);
        response.EnsureSuccessStatusCode();
        using var document = await JsonDocument.ParseAsync(await response.Content.ReadAsStreamAsync(cancellationToken), cancellationToken: cancellationToken);
        if (document.RootElement.ValueKind != JsonValueKind.Array)
            throw new InvalidOperationException("Odoo devolvió una respuesta de productos con formato inesperado.");
        return document.RootElement.EnumerateArray().Select(item => item.Clone()).ToList();
    }

    private static Product Map(JsonElement row)
    {
        var categoryIds = new List<int>();
        if (row.TryGetProperty("categ_id", out var category) && category.ValueKind == JsonValueKind.Array && category.GetArrayLength() > 0 && category[0].TryGetInt32(out var categoryId))
            categoryIds.Add(categoryId);

        var imageUrl = ExtractImage(row);

        var id = row.GetProperty("id").GetInt32();

        var stockTracked = row.TryGetProperty("is_storable", out var storable) &&
            storable.ValueKind == JsonValueKind.True;
        var stock = stockTracked &&
            row.TryGetProperty("free_qty", out var available) &&
            available.TryGetDecimal(out var quantity) && quantity > 0
                ? (int)Math.Floor(quantity)
                : 0;

        return new Product(
            id,
            ReadRelationName(row, "name") ?? "Producto sin nombre",
            ReadRelationName(row, "description_sale"),
            row.TryGetProperty("list_price", out var price) && price.TryGetDecimal(out var amount) ? amount : 0m,
            imageUrl,
            categoryIds,
            stock,
            stockTracked);
    }

    private static string? ReadRelationName(JsonElement row, string field)
    {
        if (!row.TryGetProperty(field, out var value)) return null;
        if (value.ValueKind == JsonValueKind.String) return value.GetString();
        if (value.ValueKind == JsonValueKind.Array && value.GetArrayLength() > 1) return value[1].GetString();
        return null;
    }

    private static string? ExtractImage(JsonElement row)
    {
        string[] candidateFields = ["image_1920", "image_512", "image_256", "image_128"];
        foreach (var field in candidateFields)
        {
            if (!row.TryGetProperty(field, out var imageProp))
                continue;

            if (imageProp.ValueKind == JsonValueKind.Object)
            {
                if (imageProp.TryGetProperty("content", out var contentProp) && contentProp.ValueKind == JsonValueKind.String)
                {
                    var content = contentProp.GetString();
                    if (!string.IsNullOrWhiteSpace(content))
                    {
                        var filename = imageProp.TryGetProperty("filename", out var fn) && fn.ValueKind == JsonValueKind.String ? fn.GetString() : null;
                        return FormatDataUri(content, filename);
                    }
                }
            }
            else if (imageProp.ValueKind == JsonValueKind.String)
            {
                var str = imageProp.GetString();
                if (!string.IsNullOrWhiteSpace(str))
                    return FormatDataUri(str, null);
            }
        }
        return null;
    }

    private static string FormatDataUri(string raw, string? filename)
    {
        raw = raw.Trim();
        if (raw.StartsWith("data:image", StringComparison.OrdinalIgnoreCase))
            return raw;

        var mime = "image/jpeg";
        if (!string.IsNullOrWhiteSpace(filename))
        {
            var ext = Path.GetExtension(filename).ToLowerInvariant();
            mime = ext switch
            {
                ".png" => "image/png",
                ".webp" => "image/webp",
                ".gif" => "image/gif",
                ".svg" => "image/svg+xml",
                _ => "image/jpeg"
            };
        }
        else
        {
            if (raw.StartsWith("iVBORw0KGgo", StringComparison.Ordinal))
                mime = "image/png";
            else if (raw.StartsWith("UklGR", StringComparison.Ordinal))
                mime = "image/webp";
            else if (raw.StartsWith("R0lGOD", StringComparison.Ordinal))
                mime = "image/gif";
        }

        return $"data:{mime};base64,{raw}";
    }
}
