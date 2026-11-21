using ECommerce.Domain.Orders;

namespace ECommerce.WebApi.Contracts;

public sealed record CreateOrderItemDto(int ProductId, int Quantity);

public sealed record CreateOrderApiRequest(IReadOnlyList<CreateOrderItemDto> Items);

public sealed record OrderItemDto(int ProductId, string ProductName, int Quantity, decimal UnitPrice, decimal Subtotal)
{
    public static OrderItemDto From(OrderItem item) =>
        new(item.ProductId, item.ProductName, item.Quantity, item.UnitPrice, item.Subtotal);
}

public sealed record OrderResponse(
    int Id,
    string Name,
    int PartnerId,
    string PartnerName,
    string State,
    decimal AmountTotal,
    DateTime CreatedAt,
    IReadOnlyList<OrderItemDto> Items)
{
    public static OrderResponse From(Order order) => new(
        order.Id,
        order.Name,
        order.PartnerId,
        order.PartnerName,
        order.State,
        order.AmountTotal,
        order.CreatedAt,
        order.Items.Select(OrderItemDto.From).ToArray());
}

