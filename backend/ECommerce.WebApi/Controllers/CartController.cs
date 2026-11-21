using System.Security.Claims;
using ECommerce.Infrastructure.Carts;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace ECommerce.WebApi.Controllers;

[ApiController]
[Route("api/cart")]
[Authorize]
public sealed class CartController(IAccountCartStore cartStore) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<CartResponse>> Get(CancellationToken cancellationToken)
    {
        if (!TryGetCustomerId(out var customerId)) return Unauthorized();
        var items = await cartStore.GetAsync(customerId, cancellationToken);
        return Ok(new CartResponse(items));
    }

    [HttpPut]
    public async Task<IActionResult> Replace(
        [FromBody] ReplaceCartRequest request,
        CancellationToken cancellationToken)
    {
        if (!TryGetCustomerId(out var customerId)) return Unauthorized();
        if (request.Items is null || request.Items.Count > 200 || request.Items.Any(item =>
                item.ProductId <= 0 || item.Quantity is < 1 or > 9999 ||
                string.IsNullOrWhiteSpace(item.ProductName) || item.ProductName.Length > 300 ||
                item.UnitPrice < 0 || item.CategoryIds is null || item.CategoryIds.Length > 100 ||
                item.CategoryIds.Any(id => id <= 0) ||
                item.Description?.Length > 4000 || item.ImageUrl?.Length > 2048 || item.Stock < 0))
        {
            return BadRequest(new ProblemDetails
            {
                Title = "Carrito inválido",
                Detail = "Verifica los productos y sus cantidades.",
                Status = StatusCodes.Status400BadRequest
            });
        }

        var uniqueItems = request.Items
            .GroupBy(item => item.ProductId)
            .Select(group => group.Last())
            .ToArray();
        await cartStore.SaveAsync(customerId, uniqueItems, cancellationToken);
        return NoContent();
    }

    private bool TryGetCustomerId(out int customerId) =>
        int.TryParse(User.FindFirstValue(ClaimTypes.NameIdentifier), out customerId) && customerId > 0;
}

public sealed record ReplaceCartRequest(IReadOnlyList<AccountCartItem>? Items);
public sealed record CartResponse(IReadOnlyList<AccountCartItem> Items);
