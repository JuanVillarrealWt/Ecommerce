using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using ECommerce.Application.Categories;
using ECommerce.Domain.Categories;
using Microsoft.Extensions.Options;

namespace ECommerce.Infrastructure.Odoo;

public sealed class OdooCategoryCatalog(HttpClient http, IOptions<OdooOptions> options) : ICategoryCatalog
{
    private readonly OdooOptions _options = options.Value;

    public async Task<IReadOnlyList<Category>> GetCategoriesAsync(CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(_options.ApiKey) || string.IsNullOrWhiteSpace(_options.Database))
            throw new InvalidOperationException("Falta configurar Odoo:Database y Odoo:ApiKey.");

        using var request = new HttpRequestMessage(HttpMethod.Post, "/json/2/product.category/search_read");
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _options.ApiKey);
        request.Headers.Add("X-Odoo-Database", _options.Database);
        request.Content = JsonContent.Create(new
        {
            domain = Array.Empty<object>(),
            fields = new[] { "id", "name", "parent_id" },
            limit = 100
        });

        using var response = await http.SendAsync(request, cancellationToken);
        response.EnsureSuccessStatusCode();

        using var document = await JsonDocument.ParseAsync(await response.Content.ReadAsStreamAsync(cancellationToken), cancellationToken: cancellationToken);
        if (document.RootElement.ValueKind != JsonValueKind.Array)
            return Array.Empty<Category>();

        var categories = new List<Category>();
        foreach (var item in document.RootElement.EnumerateArray())
        {
            var id = item.GetProperty("id").GetInt32();
            var name = item.TryGetProperty("name", out var n) ? n.GetString() ?? $"Categoría {id}" : $"Categoría {id}";

            int? parentId = null;
            if (item.TryGetProperty("parent_id", out var p) && p.ValueKind == JsonValueKind.Array && p.GetArrayLength() > 0 && p[0].TryGetInt32(out var pid))
                parentId = pid;

            categories.Add(new Category(id, name, parentId));
        }

        return categories;
    }
}

