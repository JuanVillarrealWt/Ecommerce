using ECommerce.Application.Orders;
using ECommerce.WebApi.Contracts;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace ECommerce.WebApi.Controllers;

[ApiController]
[Route("api/orders")]
[Authorize]
public sealed class OrdersController(
    CreateOrder createOrder,
    GetCustomerOrders getCustomerOrders,
    GetCustomerOrderDetail getCustomerOrderDetail) : ControllerBase
{
    private int GetAuthenticatedPartnerId()
    {
        var claim = User.FindFirst("partner_id")?.Value;
        if (int.TryParse(claim, out var partnerId) && partnerId > 0)
            return partnerId;

        throw new UnauthorizedAccessException("El token no contiene un identificador de contacto (partner_id) válido.");
    }

    [HttpPost]
    [ProducesResponseType<OrderResponse>(StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<OrderResponse>> Create([FromBody] CreateOrderApiRequest request, CancellationToken cancellationToken)
    {
        try
        {
            var partnerId = GetAuthenticatedPartnerId();
            var items = request.Items.Select(i => new CreateOrderItemRequest(i.ProductId, i.Quantity)).ToArray();
            var clientRef = $"MOB-{DateTime.UtcNow:yyyyMMddHHmmss}-{partnerId}";

            var order = await createOrder.ExecuteAsync(partnerId, clientRef, items, cancellationToken);
            return StatusCode(StatusCodes.Status201Created, OrderResponse.From(order));
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new ProblemDetails { Title = "Solicitud inválida", Detail = ex.Message, Status = StatusCodes.Status400BadRequest });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new ProblemDetails { Title = "Error de validación comercial", Detail = ex.Message, Status = StatusCodes.Status400BadRequest });
        }
    }

    [HttpGet]
    [ProducesResponseType<IReadOnlyList<OrderResponse>>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<IReadOnlyList<OrderResponse>>> List(CancellationToken cancellationToken)
    {
        var partnerId = GetAuthenticatedPartnerId();
        var orders = await getCustomerOrders.ExecuteAsync(partnerId, cancellationToken);
        return Ok(orders.Select(OrderResponse.From).ToArray());
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
            return order is null ? NotFound() : Ok(OrderResponse.From(order));
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
}

