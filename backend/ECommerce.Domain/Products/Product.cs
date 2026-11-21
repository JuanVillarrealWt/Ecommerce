namespace ECommerce.Domain.Products;

public sealed record Product(
    int Id,
    string Name,
    string? Description,
    decimal Price,
    string? ImageUrl,
    IReadOnlyList<int> CategoryIds,
    int Stock,
    bool StockTracked = true);
