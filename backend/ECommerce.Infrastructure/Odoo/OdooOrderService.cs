using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using ECommerce.Application.Orders;
using ECommerce.Domain.Orders;
using Microsoft.Extensions.Options;

namespace ECommerce.Infrastructure.Odoo;

public sealed class OdooOrderService(HttpClient http, IOptions<OdooOptions> options) : IOrderService
{
    private readonly OdooOptions _options = options.Value;

    public async Task<Order> CreateOrderAsync(
        int partnerId,
        string clientOrderRef,
        IReadOnlyList<(int ProductId, int Quantity, decimal UnitPrice)> items,
        CancellationToken cancellationToken = default)
    {
        ValidateCredentials();

        // 1. Preparar líneas según la especificación JSON-2: comando [0, 0, { product_id, product_uom_qty, price_unit }]
        var orderLines = items.Select(item => new object[]
        {
            0,
            0,
            new Dictionary<string, object>
            {
                ["product_id"] = item.ProductId,
                ["product_uom_qty"] = item.Quantity,
                ["price_unit"] = (double)item.UnitPrice
            }
        }).ToArray();

        // 2. Crear cotización con /json/2/sale.order/create
        using var createRequest = CreateOdooRequest(HttpMethod.Post, "/json/2/sale.order/create", new
        {
            vals_list = new[]
            {
                new Dictionary<string, object>
                {
                    ["partner_id"] = partnerId,
                    ["client_order_ref"] = clientOrderRef,
                    ["order_line"] = orderLines
                }
            }
        });

        using var createResponse = await http.SendAsync(createRequest, cancellationToken);
        if (!createResponse.IsSuccessStatusCode)
        {
            var errContent = await createResponse.Content.ReadAsStringAsync(cancellationToken);
            throw new InvalidOperationException($"Error de Odoo al crear pedido ({createResponse.StatusCode}): {errContent}");
        }

        using var createDoc = await JsonDocument.ParseAsync(await createResponse.Content.ReadAsStreamAsync(cancellationToken), cancellationToken: cancellationToken);
        if (createDoc.RootElement.ValueKind != JsonValueKind.Array || createDoc.RootElement.GetArrayLength() == 0)
            throw new InvalidOperationException("Odoo no devolvió el identificador del pedido creado.");

        var orderId = createDoc.RootElement[0].GetInt32();

        // 3. Confirmar cotización a Orden de Venta con /json/2/sale.order/action_confirm
        using var confirmRequest = CreateOdooRequest(HttpMethod.Post, "/json/2/sale.order/action_confirm", new
        {
            ids = new[] { orderId },
            context = new { }
        });

        using var confirmResponse = await http.SendAsync(confirmRequest, cancellationToken);
        if (!confirmResponse.IsSuccessStatusCode)
        {
            var errContent = await confirmResponse.Content.ReadAsStringAsync(cancellationToken);
            throw new InvalidOperationException($"Error de Odoo al confirmar pedido ({confirmResponse.StatusCode}): {errContent}");
        }

        var orderItems = items.Select(i => new OrderItem(i.ProductId, $"Producto {i.ProductId}", i.Quantity, i.UnitPrice)).ToList();
        // La orden ya fue creada y confirmada; no esperar otra consulta de lectura a Odoo.
        return new Order(orderId, $"SO{orderId:D5}", partnerId, "Cliente", "sale", items.Sum(i => i.Quantity * i.UnitPrice), DateTime.UtcNow, orderItems);
    }

    public async Task<IReadOnlyList<Order>> GetCustomerOrdersAsync(int partnerId, CancellationToken cancellationToken = default)
    {
        ValidateCredentials();

        using var request = CreateOdooRequest(HttpMethod.Post, "/json/2/sale.order/search_read", new
        {
            domain = new object[]
            {
                new object[] { "partner_id", "=", partnerId }
            },
            fields = new[] { "id", "name", "partner_id", "state", "amount_total", "date_order", "order_line" },
            limit = 50
        });

        using var response = await http.SendAsync(request, cancellationToken);
        response.EnsureSuccessStatusCode();

        using var doc = await JsonDocument.ParseAsync(await response.Content.ReadAsStreamAsync(cancellationToken), cancellationToken: cancellationToken);
        if (doc.RootElement.ValueKind != JsonValueKind.Array)
            return Array.Empty<Order>();

        var list = new List<Order>();
        foreach (var row in doc.RootElement.EnumerateArray())
        {
            list.Add(MapOrder(row, Array.Empty<OrderItem>()));
        }

        return list;
    }

    public async Task<Order?> GetOrderByIdAsync(int orderId, CancellationToken cancellationToken = default)
    {
        ValidateCredentials();

        using var request = CreateOdooRequest(HttpMethod.Post, "/json/2/sale.order/search_read", new
        {
            domain = new object[]
            {
                new object[] { "id", "=", orderId }
            },
            fields = new[] { "id", "name", "partner_id", "state", "amount_total", "date_order", "order_line" },
            limit = 1
        });

        using var response = await http.SendAsync(request, cancellationToken);
        response.EnsureSuccessStatusCode();

        using var doc = await JsonDocument.ParseAsync(await response.Content.ReadAsStreamAsync(cancellationToken), cancellationToken: cancellationToken);
        if (doc.RootElement.ValueKind != JsonValueKind.Array || doc.RootElement.GetArrayLength() == 0)
            return null;

        var row = doc.RootElement[0];

        // Leer líneas detalladas si existen
        var lineIds = new List<int>();
        if (row.TryGetProperty("order_line", out var ol) && ol.ValueKind == JsonValueKind.Array)
        {
            foreach (var item in ol.EnumerateArray())
            {
                if (item.TryGetInt32(out var lid)) lineIds.Add(lid);
            }
        }

        var items = await FetchOrderLinesAsync(lineIds, cancellationToken);
        return MapOrder(row, items);
    }

    private async Task<IReadOnlyList<OrderItem>> FetchOrderLinesAsync(IReadOnlyList<int> lineIds, CancellationToken cancellationToken)
    {
        if (lineIds.Count == 0) return Array.Empty<OrderItem>();

        using var request = CreateOdooRequest(HttpMethod.Post, "/json/2/sale.order.line/search_read", new
        {
            domain = new object[]
            {
                new object[] { "id", "in", lineIds.ToArray() }
            },
            fields = new[] { "id", "name", "product_id", "product_uom_qty", "price_unit" }
        });

        using var response = await http.SendAsync(request, cancellationToken);
        if (!response.IsSuccessStatusCode) return Array.Empty<OrderItem>();

        using var doc = await JsonDocument.ParseAsync(await response.Content.ReadAsStreamAsync(cancellationToken), cancellationToken: cancellationToken);
        if (doc.RootElement.ValueKind != JsonValueKind.Array) return Array.Empty<OrderItem>();

        var lines = new List<OrderItem>();
        foreach (var item in doc.RootElement.EnumerateArray())
        {
            var pId = 0;
            var pName = item.TryGetProperty("name", out var n) ? n.GetString() ?? "Producto" : "Producto";

            if (item.TryGetProperty("product_id", out var pi) && pi.ValueKind == JsonValueKind.Array && pi.GetArrayLength() > 0)
            {
                pi[0].TryGetInt32(out pId);
                if (pi.GetArrayLength() > 1) pName = pi[1].GetString() ?? pName;
            }

            var qty = item.TryGetProperty("product_uom_qty", out var q) && q.TryGetDecimal(out var qVal) ? (int)qVal : 1;
            var price = item.TryGetProperty("price_unit", out var p) && p.TryGetDecimal(out var pVal) ? pVal : 0m;

            lines.Add(new OrderItem(pId, pName, qty, price));
        }

        return lines;
    }

    private static Order MapOrder(JsonElement row, IReadOnlyList<OrderItem> items)
    {
        var id = row.GetProperty("id").GetInt32();
        var name = row.TryGetProperty("name", out var n) ? n.GetString() ?? $"Pedido {id}" : $"Pedido {id}";

        var partnerId = 0;
        var partnerName = "Consumidor";
        if (row.TryGetProperty("partner_id", out var p) && p.ValueKind == JsonValueKind.Array && p.GetArrayLength() > 0)
        {
            p[0].TryGetInt32(out partnerId);
            if (p.GetArrayLength() > 1) partnerName = p[1].GetString() ?? partnerName;
        }

        var state = row.TryGetProperty("state", out var s) ? s.GetString() ?? "draft" : "draft";
        var amountTotal = row.TryGetProperty("amount_total", out var a) && a.TryGetDecimal(out var av) ? av : 0m;

        var createdAt = DateTime.UtcNow;
        if (row.TryGetProperty("date_order", out var d) && d.TryGetDateTime(out var dt))
            createdAt = dt;

        return new Order(id, name, partnerId, partnerName, state, amountTotal, createdAt, items);
    }

    private static readonly JsonSerializerOptions OdooJsonOptions = new()
    {
        PropertyNamingPolicy = null
    };

    private HttpRequestMessage CreateOdooRequest<T>(HttpMethod method, string path, T content)
    {
        var request = new HttpRequestMessage(method, path);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _options.ApiKey);
        request.Headers.Add("X-Odoo-Database", _options.Database);
        var json = JsonSerializer.Serialize(content, content?.GetType() ?? typeof(T), OdooJsonOptions);
        request.Content = new StringContent(json, Encoding.UTF8, "application/json");
        return request;
    }

    private void ValidateCredentials()
    {
        if (string.IsNullOrWhiteSpace(_options.ApiKey) || string.IsNullOrWhiteSpace(_options.Database))
            throw new InvalidOperationException("Falta configurar Odoo:Database y Odoo:ApiKey.");
    }
}

