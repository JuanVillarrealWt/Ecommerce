using ECommerce.Domain.Products;

namespace ECommerce.WebApi.Contracts;

public sealed record ProductResponse(
    int Id,
    string Name,
    string? Description,
    decimal Price,
    string? ImageUrl,
    IReadOnlyList<int> CategoryIds)
{
    public static ProductResponse From(Product product) => new(
        product.Id,
        product.Name,
        product.Description,
        product.Price,
        product.ImageUrl,
        product.CategoryIds);
}
