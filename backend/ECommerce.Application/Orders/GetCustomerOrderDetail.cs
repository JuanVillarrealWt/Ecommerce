using ECommerce.Domain.Orders;

namespace ECommerce.Application.Orders;

public sealed class GetCustomerOrderDetail(
    IOrderService orderService,
    IOrderSnapshotStore orderSnapshots)
{
    public async Task<Order?> ExecuteAsync(int orderId, int customerPartnerId, CancellationToken cancellationToken = default)
    {
        if (orderId <= 0)
            return null;

        Order? order = null;
        try
        {
            order = await orderService.GetOrderByIdAsync(orderId, cancellationToken);
        }
        catch
        {
            // Odoo connection might fail; fallback to snapshot below
        }

        if (order is null)
        {
            var snapshot = await orderSnapshots.GetAsync(orderId, cancellationToken);
            if (snapshot is not null && snapshot.PartnerId == customerPartnerId && snapshot.State is ("sale" or "done"))
                return snapshot;
            return null;
        }

        if (order.PartnerId != customerPartnerId)
            throw new UnauthorizedAccessException("No tiene autorización para consultar un pedido perteneciente a otro cliente.");

        if (order.State is not ("sale" or "done"))
            return null;

        return await orderSnapshots.CaptureIfMissingAsync(order, cancellationToken);
    }
}

