using ECommerce.Domain.Orders;

namespace ECommerce.Application.Orders;

public sealed class GetCustomerOrders(IOrderService orderService)
{
    public Task<IReadOnlyList<Order>> ExecuteAsync(int partnerId, CancellationToken cancellationToken = default)
    {
        if (partnerId <= 0)
            throw new ArgumentOutOfRangeException(nameof(partnerId), "Identificador de cliente inválido.");

        return orderService.GetCustomerOrdersAsync(partnerId, cancellationToken);
    }
}
