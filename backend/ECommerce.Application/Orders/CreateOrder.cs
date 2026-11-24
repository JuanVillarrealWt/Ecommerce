using ECommerce.Application.Products;
using ECommerce.Domain.Orders;

namespace ECommerce.Application.Orders;

public record CreateOrderItemRequest(int ProductId, int Quantity);

public sealed class CreateOrder(IOrderService orderService, IProductCatalog productCatalog)
{
    public async Task<Order> ExecuteAsync(
        int partnerId,
        string clientOrderRef,
        IReadOnlyList<CreateOrderItemRequest> items,
        IReadOnlyDictionary<int, decimal>? discounts = null,
        OrderDeliveryAddress? deliveryAddress = null,
        CancellationToken cancellationToken = default)
    {
        if (partnerId <= 0)
            throw new ArgumentOutOfRangeException(nameof(partnerId), "El identificador del cliente debe ser mayor a cero.");

        if (items is null || items.Count == 0)
            throw new ArgumentException("El pedido debe contener al menos un producto.", nameof(items));

        var validatedLines = new List<(int ProductId, int Quantity, decimal UnitPrice)>();

        foreach (var item in items)
        {
            if (item.Quantity <= 0)
                throw new ArgumentOutOfRangeException(nameof(items), $"La cantidad del producto ID {item.ProductId} debe ser mayor a cero.");

            var product = await productCatalog.GetProductForOrderAsync(item.ProductId, cancellationToken);
            if (product is null)
                throw new InvalidOperationException($"El producto con ID {item.ProductId} no existe o no está disponible para venta.");

            if (!product.StockTracked)
                throw new InvalidOperationException($"El inventario de '{product.Name}' no está configurado en Odoo. No se puede confirmar la compra con cantidades no verificadas.");

            if (item.Quantity > product.Stock)
                throw new InvalidOperationException($"Stock insuficiente para '{product.Name}'. Disponible: {product.Stock}, solicitado: {item.Quantity}.");

            // Validar con el precio real vigente en Odoo (RN-02 / RN-06)
            var price = (decimal)product.Price;
            if (discounts is not null && discounts.TryGetValue(product.Id, out var percentage))
                price = decimal.Round(price * (100m - percentage) / 100m, 2, MidpointRounding.AwayFromZero);
            validatedLines.Add((product.Id, item.Quantity, price));
        }

        return await orderService.CreateDraftOrderAsync(
            partnerId, clientOrderRef, validatedLines, deliveryAddress, cancellationToken);
    }
}

