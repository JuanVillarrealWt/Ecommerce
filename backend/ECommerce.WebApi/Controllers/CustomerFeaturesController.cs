using System.Text.RegularExpressions;
using ECommerce.Application.CustomerFeatures;
using ECommerce.Application.Orders;
using ECommerce.Application.Customers;
using ECommerce.Domain.Orders;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace ECommerce.WebApi.Controllers;

[ApiController]
[Route("api/customer/features")]
[Authorize]
public sealed class CustomerFeaturesController(
    ManageCustomerFeatures features,
    GetCustomerOrders getOrders,
    GetCustomerOrderDetail getOrder,
    ICustomerService customers,
    IOrderSnapshotStore orderSnapshots) : ControllerBase
{
    private static readonly HashSet<string> EcuadorProvinces = new(StringComparer.OrdinalIgnoreCase)
    {
        "Azuay", "Bolívar", "Cañar", "Carchi", "Chimborazo", "Cotopaxi", "El Oro", "Esmeraldas",
        "Galápagos", "Guayas", "Imbabura", "Loja", "Los Ríos", "Manabí", "Morona Santiago", "Napo",
        "Orellana", "Pastaza", "Pichincha", "Santa Elena", "Santo Domingo de los Tsáchilas", "Sucumbíos",
        "Tungurahua", "Zamora Chinchipe"
    };

    private int PartnerId => int.TryParse(User.FindFirst("partner_id")?.Value, out var id) && id > 0
        ? id
        : throw new UnauthorizedAccessException("El token no contiene un partner_id válido.");

    [HttpGet]
    public async Task<CustomerFeaturesData> Get(CancellationToken ct)
    {
        var partnerId = PartnerId;
        var orders = await getOrders.ExecuteAsync(partnerId, ct);
        await features.UpdateAsync(partnerId, data =>
        {
            foreach (var order in orders)
            {
                var state = order.State;
                if (data.OrderStates.TryGetValue(order.Id, out var previous) && previous != state)
                    data.Notifications.Insert(0, new CustomerNotification(Guid.NewGuid(), "order", $"Actualización de {order.Name}", $"El estado de tu pedido cambió a {state}.", order.Id, DateTime.UtcNow, false));
                data.OrderStates[order.Id] = state;
            }
            if (data.Notifications.Count > 100) data.Notifications = data.Notifications.Take(100).ToList();
        }, ct);
        var data = await features.GetAsync(partnerId, ct);
        var snapshots = await orderSnapshots.GetByPartnerIdAsync(partnerId, ct);
        data.PurchasedProductIds = snapshots
            .Where(o => o.State is "sale" or "done")
            .SelectMany(o => o.Items.Select(i => i.ProductId))
            .Distinct()
            .ToList();
        return data;
    }

    [HttpPost("favorites/{productId:int}")]
    public async Task<IActionResult> AddFavorite(int productId, CancellationToken ct)
    {
        if (productId <= 0) return BadRequest();
        await features.UpdateAsync(PartnerId, data =>
        {
            if (!data.FavoriteProductIds.Contains(productId)) data.FavoriteProductIds.Add(productId);
        }, ct);
        return NoContent();
    }

    [HttpDelete("favorites/{productId:int}")]
    public async Task<IActionResult> RemoveFavorite(int productId, CancellationToken ct)
    {
        await features.UpdateAsync(PartnerId, data => data.FavoriteProductIds.Remove(productId), ct);
        return NoContent();
    }

    [HttpGet("products/{productId:int}/review-order")]
    public async Task<ActionResult<int>> GetReviewOrder(int productId, CancellationToken ct)
    {
        if (productId <= 0) return BadRequest();
        var partnerId = PartnerId;

        // 1. Buscar en snapshots locales primero
        var snapshots = await orderSnapshots.GetByPartnerIdAsync(partnerId, ct);
        var snapshotOrder = snapshots
            .Where(item => item.State is "sale" or "done")
            .Where(item => item.Items.Any(product => product.ProductId == productId))
            .OrderByDescending(item => item.CreatedAt)
            .FirstOrDefault();
        if (snapshotOrder is not null)
            return Ok(snapshotOrder.Id);

        // 2. Buscar en pedidos de Odoo consultando detalle si hiciera falta
        try
        {
            var orders = await getOrders.ExecuteAsync(partnerId, ct);
            foreach (var summary in orders.Where(item => item.State is "sale" or "done").OrderByDescending(item => item.CreatedAt))
            {
                var detail = await getOrder.ExecuteAsync(summary.Id, partnerId, ct);
                if (detail is not null && detail.Items.Any(p => p.ProductId == productId))
                {
                    return Ok(detail.Id);
                }
            }
        }
        catch
        {
            // Odoo podría estar sin conexión
        }

        return NoContent();
    }

    [HttpGet("products/{productId:int}/reviews")]
    [AllowAnonymous]
    public async Task<IActionResult> GetProductReviews(int productId, CancellationToken ct)
    {
        if (productId <= 0) return BadRequest();
        var reviews = await features.GetProductReviewsAsync(productId, ct);
        var oneRatingPerCustomer = reviews
            .GroupBy(review => review.PartnerId)
            .Select(group => group.OrderByDescending(review => review.CreatedAt).First())
            .OrderByDescending(review => review.CreatedAt);
        return Ok(oneRatingPerCustomer.Select(review => new
        {
            review.Id,
            review.ProductId,
            review.CustomerName,
            review.Rating,
            review.Comment,
            review.CreatedAt
        }));
    }

    [HttpPost("addresses")]
    public async Task<ActionResult<SavedAddress>> SaveAddress([FromBody] SaveAddressRequest request, CancellationToken ct)
    {
        var label = request.Label?.Trim() ?? string.Empty;
        var recipient = request.Recipient?.Trim() ?? string.Empty;
        var street = request.Street?.Trim() ?? string.Empty;
        var city = request.City?.Trim() ?? string.Empty;
        var province = request.Province?.Trim() ?? string.Empty;
        var postalCode = request.PostalCode?.Trim() ?? string.Empty;
        var phone = request.Phone?.Trim() ?? string.Empty;
        if (string.IsNullOrWhiteSpace(label) || label.Length > 50)
            return BadRequest("La etiqueta de la dirección es obligatoria y admite hasta 50 caracteres.");
        if (string.IsNullOrWhiteSpace(recipient) || recipient.Length > 50 || !Regex.IsMatch(recipient, @"^[\p{L}]+(?:[ '-][\p{L}]+)*$"))
            return BadRequest("Escribe un nombre válido para quien recibe el pedido.");
        if (string.IsNullOrWhiteSpace(street) || street.Length > 50 || street.Contains("  ", StringComparison.Ordinal) || !Regex.IsMatch(street, @"^[\p{L}0-9#.,/' -]+$"))
            return BadRequest("Escribe una dirección válida de hasta 50 caracteres.");
        if (string.IsNullOrWhiteSpace(city) || city.Length > 50 || !Regex.IsMatch(city, @"^[\p{L}]+(?:[ '-][\p{L}]+)*$"))
            return BadRequest("Escribe una ciudad válida.");
        if (string.IsNullOrWhiteSpace(province) || !EcuadorProvinces.Contains(province))
            return BadRequest("Selecciona una provincia de Ecuador.");
        if (!Regex.IsMatch(postalCode, @"^\d{6}$"))
            return BadRequest("El código postal debe tener 6 números.");
        if (!Regex.IsMatch(phone, @"^09\d{8}$"))
            return BadRequest("El celular debe tener 10 dígitos y comenzar con 09.");
        var partnerId = PartnerId;
        var existing = await features.GetAsync(partnerId, ct);
        var isPrimary = existing.Addresses.Count == 0;
        if (isPrimary)
        {
            try { await customers.UpdatePrimaryAddressAsync(partnerId, street, city, province, postalCode, phone, ct); }
            catch (Exception ex) when (ex is InvalidOperationException or KeyNotFoundException or HttpRequestException or CustomerSyncException)
            { return StatusCode(StatusCodes.Status503ServiceUnavailable, new ProblemDetails { Title = "No se pudo actualizar Odoo", Detail = "No se guardó la dirección principal porque no se pudo sincronizar el contacto en Odoo." }); }
        }
        SavedAddress? saved = null;
        var data = await features.UpdateAsync(PartnerId, current =>
        {
            var id = Guid.NewGuid();
            if (request.IsDefault) current.Addresses = current.Addresses.Select(address => address with { IsDefault = false }).ToList();
            saved = new SavedAddress(id, label, recipient, street, city, province, postalCode, phone, isPrimary || request.IsDefault, isPrimary || request.IsDefault ? partnerId : null);
            current.Addresses.Add(saved);
        }, ct);
        return Ok(saved);
    }

    [HttpPut("addresses/{id:guid}")]
    public async Task<IActionResult> UpdateAddress(Guid id, [FromBody] SaveAddressRequest request, CancellationToken ct)
    {
        var label = request.Label?.Trim() ?? string.Empty; var recipient = request.Recipient?.Trim() ?? string.Empty;
        var street = request.Street?.Trim() ?? string.Empty; var city = request.City?.Trim() ?? string.Empty;
        var province = request.Province?.Trim() ?? string.Empty; var postalCode = request.PostalCode?.Trim() ?? string.Empty; var phone = request.Phone?.Trim() ?? string.Empty;
        var error = ValidateAddress(label, recipient, street, city, province, postalCode, phone);
        if (error is not null) return BadRequest(error);
        var partnerId = PartnerId;
        var current = await features.GetAsync(partnerId, ct);
        var address = current.Addresses.FirstOrDefault(item => item.Id == id);
        if (address is null) return NotFound();
        if (address.IsDefault)
        {
            try { await customers.UpdatePrimaryAddressAsync(partnerId, street, city, province, postalCode, phone, ct); }
            catch (Exception ex) when (ex is InvalidOperationException or KeyNotFoundException or HttpRequestException or CustomerSyncException)
            { return StatusCode(StatusCodes.Status503ServiceUnavailable, new ProblemDetails { Title = "No se pudo actualizar Odoo", Detail = "No se guardaron los cambios porque no se pudo sincronizar el contacto en Odoo." }); }
        }
        SavedAddress? updatedAddress = null;
        await features.UpdateAsync(partnerId, data =>
        {
            var index = data.Addresses.FindIndex(item => item.Id == id);
            if (index >= 0)
            {
                updatedAddress = address with { Label = label, Recipient = recipient, Street = street, City = city, Province = province, PostalCode = postalCode, Phone = phone };
                data.Addresses[index] = updatedAddress;
            }
        }, ct);
        return updatedAddress is null ? NotFound() : Ok(updatedAddress);
    }

    [HttpDelete("addresses/{id:guid}")]
    public async Task<IActionResult> DeleteAddress(Guid id, CancellationToken ct)
    {
        var partnerId = PartnerId;
        var address = (await features.GetAsync(partnerId, ct)).Addresses.FirstOrDefault(item => item.Id == id);
        if (address is null) return NotFound();
        if (address.IsDefault) return Conflict(new ProblemDetails { Title = "Dirección principal protegida", Detail = "La dirección principal no se puede eliminar; puedes editarla." });
        await features.UpdateAsync(partnerId, data => data.Addresses.RemoveAll(item => item.Id == id), ct);
        return NoContent();
    }

    private static string? ValidateAddress(string label, string recipient, string street, string city, string province, string postalCode, string phone)
    {
        if (string.IsNullOrWhiteSpace(label) || label.Length > 50) return "La etiqueta de la dirección es obligatoria y admite hasta 50 caracteres.";
        if (string.IsNullOrWhiteSpace(recipient) || recipient.Length > 50 || !Regex.IsMatch(recipient, @"^[\p{L}]+(?:[ '-][\p{L}]+)*$")) return "Escribe un nombre válido de hasta 50 caracteres para quien recibe el pedido.";
        if (string.IsNullOrWhiteSpace(street) || street.Length > 50 || street.Contains("  ", StringComparison.Ordinal) || !Regex.IsMatch(street, @"^[\p{L}0-9#.,/' -]+$")) return "Escribe una dirección válida de hasta 50 caracteres.";
        if (string.IsNullOrWhiteSpace(city) || city.Length > 50 || !Regex.IsMatch(city, @"^[\p{L}]+(?:[ '-][\p{L}]+)*$")) return "Escribe una ciudad válida de hasta 50 caracteres.";
        if (string.IsNullOrWhiteSpace(province) || !EcuadorProvinces.Contains(province)) return "Selecciona una provincia de Ecuador.";
        if (!Regex.IsMatch(postalCode, @"^\d{6}$")) return "El código postal debe tener 6 números.";
        if (!Regex.IsMatch(phone, @"^09\d{8}$")) return "El celular debe tener 10 dígitos y comenzar con 09.";
        return null;
    }

    [HttpPost("notifications/{id:guid}/read")]
    public async Task<IActionResult> MarkNotificationRead(Guid id, CancellationToken ct)
    {
        await features.UpdateAsync(PartnerId, data =>
        {
            var index = data.Notifications.FindIndex(item => item.Id == id);
            if (index >= 0) data.Notifications[index] = data.Notifications[index] with { IsRead = true };
        }, ct);
        return NoContent();
    }

    [HttpPost("reviews")]
    public async Task<IActionResult> AddReview([FromBody] CreateProductReviewRequest request, CancellationToken ct)
    {
        if (request.ProductId <= 0 || request.OrderId <= 0 || request.Rating is < 1 or > 5 || request.Comment?.Length > 1000) return BadRequest("La calificación debe ser de 1 a 5 y el comentario no puede superar 1000 caracteres.");
        var partnerId = PartnerId;
        Order? order = null;
        try { order = await getOrder.ExecuteAsync(request.OrderId, partnerId, ct); }
        catch { }
        order ??= await orderSnapshots.GetAsync(request.OrderId, ct);
        if (order is null || order.PartnerId != partnerId || (order.State is not ("sale" or "done")) || !order.Items.Any(item => item.ProductId == request.ProductId))
            return BadRequest("Solo puedes reseñar productos de tus pedidos confirmados.");
        var updated = await features.UpdateAsync(partnerId, data =>
        {
            var existing = data.Reviews
                .Where(review => review.PartnerId == partnerId && review.ProductId == request.ProductId)
                .OrderByDescending(review => review.CreatedAt)
                .FirstOrDefault();
            data.Reviews.RemoveAll(review =>
                review.PartnerId == partnerId && review.ProductId == request.ProductId);
            if (existing is not null)
            {
                data.Reviews.Add(existing with
                {
                    CustomerName = order.PartnerName,
                    OrderId = request.OrderId,
                    Rating = request.Rating,
                    Comment = request.Comment?.Trim() ?? string.Empty,
                    CreatedAt = DateTime.UtcNow
                });
            }
            else
            {
                data.Reviews.Add(new ProductReview(Guid.NewGuid(), partnerId, order.PartnerName, request.ProductId, request.OrderId, request.Rating, request.Comment?.Trim() ?? string.Empty, DateTime.UtcNow));
            }
        }, ct);
        return Ok(updated.Reviews.Last(review => review.PartnerId == partnerId && review.ProductId == request.ProductId));
    }

    [HttpDelete("reviews/{productId:int}")]
    public async Task<IActionResult> DeleteReview(int productId, CancellationToken ct)
    {
        if (productId <= 0) return BadRequest();
        var partnerId = PartnerId;
        var updated = await features.UpdateAsync(partnerId, data =>
            data.Reviews.RemoveAll(review =>
                review.PartnerId == partnerId && review.ProductId == productId), ct);
        return updated.Reviews.Any(review =>
            review.PartnerId == partnerId && review.ProductId == productId)
            ? Conflict("No se pudo eliminar la reseña.")
            : NoContent();
    }
}

public sealed record CreateProductReviewRequest(int ProductId, int OrderId, int Rating, string Comment);
