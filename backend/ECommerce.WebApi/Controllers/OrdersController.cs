using ECommerce.Application.Orders;
using ECommerce.Application.CustomerFeatures;
using ECommerce.WebApi.Contracts;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace ECommerce.WebApi.Controllers;

[ApiController]
[Route("api/orders")]
[Authorize]
public sealed class OrdersController(
    GetCustomerOrders getCustomerOrders,
    GetCustomerOrderDetail getCustomerOrderDetail,
    ManageCustomerFeatures features) : ControllerBase
{
    private int GetAuthenticatedPartnerId()
    {
        var claim = User.FindFirst("partner_id")?.Value;
        if (int.TryParse(claim, out var partnerId) && partnerId > 0)
            return partnerId;

        throw new UnauthorizedAccessException("El token no contiene un identificador de contacto (partner_id) válido.");
    }

    [HttpPost]
    [ProducesResponseType(StatusCodes.Status410Gone)]
    public IActionResult Create() => StatusCode(StatusCodes.Status410Gone, new ProblemDetails
    {
        Title = "El pago es obligatorio",
        Detail = "Inicia el pago desde POST /api/checkout/payments. La orden se confirma cuando Stripe notifica el pago.",
        Status = StatusCodes.Status410Gone
    });

    [HttpGet]
    [ProducesResponseType<IReadOnlyList<OrderResponse>>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<IReadOnlyList<OrderResponse>>> List(CancellationToken cancellationToken)
    {
        var partnerId = GetAuthenticatedPartnerId();
        var orders = await getCustomerOrders.ExecuteAsync(partnerId, cancellationToken);
        var receivedIds = (await features.GetAsync(partnerId, cancellationToken)).ReceivedOrderIds.ToHashSet();
        return Ok(orders.Select(order => OrderResponse.From(order, receivedIds.Contains(order.Id))).ToArray());
    }

    [HttpGet("{id:int}")]
    [ProducesResponseType<OrderResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<OrderResponse>> Detail(int id, CancellationToken cancellationToken)
    {
        try
        {
            var partnerId = GetAuthenticatedPartnerId();
            var order = await getCustomerOrderDetail.ExecuteAsync(id, partnerId, cancellationToken);
            if (order is null) return NotFound();
            var received = (await features.GetAsync(partnerId, cancellationToken)).ReceivedOrderIds.Contains(order.Id);
            return Ok(OrderResponse.From(order, received));
        }
        catch (UnauthorizedAccessException ex)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new ProblemDetails
            {
                Title = "Acceso denegado",
                Detail = ex.Message,
                Status = StatusCodes.Status403Forbidden
            });
        }
    }

    [HttpPost("{id:int}/received")]
    public async Task<IActionResult> MarkReceived(int id, CancellationToken cancellationToken)
    {
        var partnerId = GetAuthenticatedPartnerId();
        try
        {
            var order = await getCustomerOrderDetail.ExecuteAsync(id, partnerId, cancellationToken);
            if (order is null) return NotFound();
            await features.UpdateAsync(partnerId, data =>
            {
                if (!data.ReceivedOrderIds.Contains(id)) data.ReceivedOrderIds.Add(id);
            }, cancellationToken);
            return NoContent();
        }
        catch (UnauthorizedAccessException ex)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new ProblemDetails { Title = "Acceso denegado", Detail = ex.Message });
        }
    }
}

