using ECommerce.Domain.Orders;

namespace ECommerce.Application.Orders;

public interface IOrderService
{
    Task<Order> CreateOrderAsync(
        int partnerId,
        string clientOrderRef,
        IReadOnlyList<(int ProductId, int Quantity, decimal UnitPrice)> items,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<Order>> GetCustomerOrdersAsync(
        int partnerId,
        CancellationToken cancellationToken = default);

    Task<Order?> GetOrderByIdAsync(
        int orderId,
        CancellationToken cancellationToken = default);
}

