using ECommerce.Domain.Orders;

namespace ECommerce.Application.Orders;

/// <summary>
/// Keeps the customer and line values that appeared on an order receipt when
/// the order was first confirmed or opened after deployment.
/// </summary>
public interface IOrderSnapshotStore
{
    Task<Order?> GetAsync(
        int orderId,
        CancellationToken cancellationToken = default);

    Task<Order> CaptureIfMissingAsync(
        Order order,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<Order>> GetByPartnerIdAsync(
        int partnerId,
        CancellationToken cancellationToken = default);
}
