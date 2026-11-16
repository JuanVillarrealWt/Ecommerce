using ECommerce.Domain.Orders;

namespace ECommerce.Application.Orders;

public sealed class GetCustomerOrderDetail(IOrderService orderService)
{
    public async Task<Order?> ExecuteAsync(int orderId, int customerPartnerId, CancellationToken cancellationToken = default)
    {
        if (orderId <= 0)
            return null;

        var order = await orderService.GetOrderByIdAsync(orderId, cancellationToken);
        if (order is null)
            return null;

        if (order.PartnerId != customerPartnerId)
            throw new UnauthorizedAccessException("No tiene autorización para consultar un pedido perteneciente a otro cliente.");

        return order;
    }
}
