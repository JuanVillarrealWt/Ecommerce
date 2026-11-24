using ECommerce.Domain.Orders;

namespace ECommerce.Application.Orders;

public interface IOrderService
{
    Task<Order> CreateDraftOrderAsync(
        int partnerId,
        string clientOrderRef,
        IReadOnlyList<(int ProductId, int Quantity, decimal UnitPrice)> items,
        OrderDeliveryAddress? deliveryAddress = null,
        CancellationToken cancellationToken = default) =>
        CreateOrderAsync(partnerId, clientOrderRef, items, cancellationToken);

    async Task<Order> ConfirmOrderAsync(int orderId, CancellationToken cancellationToken = default) =>
        await GetOrderByIdAsync(orderId, cancellationToken)
            ?? throw new InvalidOperationException("El servicio de pedidos no puede confirmar esta cotización.");

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

public sealed record OrderDeliveryAddress(
    string Label,
    string Recipient,
    string Street,
    string City,
    string Province,
    string PostalCode,
    string Phone);

