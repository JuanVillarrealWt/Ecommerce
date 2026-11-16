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

    public async Task<IReadOnlyList<Product>> GetProductsAsync(int? categoryId = null, CancellationToken cancellationToken = default)
    {
        var criteria = new List<object>
        {
            new object[] { "active", "=", true },
            new object[] { "sale_ok", "=", true }
        };

        if (categoryId.HasValue && categoryId.Value > 0)
        {
            criteria.Add(new object[] { "categ_id", "=", categoryId.Value });
        }

        var rows = await SearchReadAsync(criteria.ToArray(), cancellationToken);
        return rows.Select(Map).ToArray();
    }

    public async Task<Product?> GetProductAsync(int id, CancellationToken cancellationToken = default)
    {
        var rows = await SearchReadAsync(new object[]
        {
            new object[] { "id", "=", id },
            new object[] { "active", "=", true },
            new object[] { "sale_ok", "=", true }
        }, cancellationToken);
        return rows.Count == 0 ? null : Map(rows[0]);
    }

    private async Task<List<JsonElement>> SearchReadAsync(object? domain, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(_options.ApiKey) || string.IsNullOrWhiteSpace(_options.Database))
            throw new InvalidOperationException("Falta configurar Odoo:Database y Odoo:ApiKey (usar variables de entorno o secretos de usuario).");

        using var request = new HttpRequestMessage(HttpMethod.Post, "/json/2/product.product/search_read");
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _options.ApiKey);
        request.Headers.Add("X-Odoo-Database", _options.Database);
        request.Content = JsonContent.Create(new
        {
            domain,
            fields = new[] { "id", "name", "description_sale", "list_price", "image_128", "categ_id", "active", "sale_ok" },
            limit = 100,
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

        string? imageUrl = null;
        if (row.TryGetProperty("image_128", out var image) && image.ValueKind == JsonValueKind.String && !string.IsNullOrEmpty(image.GetString()))
            imageUrl = "data:image/jpeg;base64," + image.GetString();

        return new Product(
            row.GetProperty("id").GetInt32(),
            ReadRelationName(row, "name") ?? "Producto sin nombre",
            ReadRelationName(row, "description_sale"),
            row.TryGetProperty("list_price", out var price) && price.TryGetDecimal(out var amount) ? amount : 0m,
            imageUrl,
            categoryIds);
    }

    private static string? ReadRelationName(JsonElement row, string field)
    {
        if (!row.TryGetProperty(field, out var value)) return null;
        if (value.ValueKind == JsonValueKind.String) return value.GetString();
        if (value.ValueKind == JsonValueKind.Array && value.GetArrayLength() > 1) return value[1].GetString();
        return null;
    }
}
