using ECommerce.Domain.Products;

namespace ECommerce.Application.Products;

public interface IProductCatalog
{
    Task<IReadOnlyList<Product>> GetProductsAsync(int? categoryId = null, CancellationToken cancellationToken = default);
    Task<Product?> GetProductAsync(int id, CancellationToken cancellationToken = default);

    // Order validation only needs the cached commercial fields, never the product image.
    Task<Product?> GetProductForOrderAsync(int id, CancellationToken cancellationToken = default) =>
        GetProductAsync(id, cancellationToken);
}
