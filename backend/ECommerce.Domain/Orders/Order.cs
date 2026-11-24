namespace ECommerce.Domain.Orders;

public sealed class OrderItem(int productId, string productName, int quantity, decimal unitPrice)
{
    public int ProductId { get; } = productId;
    public string ProductName { get; } = productName;
    public int Quantity { get; } = quantity;
    public decimal UnitPrice { get; } = unitPrice;
    public decimal Subtotal => Quantity * UnitPrice;
}

public sealed class Order(
    int id,
    string name,
    int partnerId,
    string partnerName,
    string state,
    decimal amountTotal,
    DateTime createdAt,
    IReadOnlyList<OrderItem> items,
    string currencyCode = "USD",
    decimal amountUntaxed = 0m,
    decimal amountTax = 0m,
    bool received = false)
{
    public int Id { get; } = id;
    public string Name { get; } = name;
    public int PartnerId { get; } = partnerId;
    public string PartnerName { get; } = partnerName;
    public string State { get; } = state; // "draft", "sale", "cancel"
    public decimal AmountTotal { get; } = amountTotal;
    public DateTime CreatedAt { get; } = createdAt;
    public IReadOnlyList<OrderItem> Items { get; } = items;
    public string CurrencyCode { get; } = currencyCode;
    public decimal AmountUntaxed { get; } = amountUntaxed;
    public decimal AmountTax { get; } = amountTax;
    public bool Received { get; } = received;
}

