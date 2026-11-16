using ECommerce.Domain.Products;

namespace ECommerce.Application.Products;

public sealed class GetProducts(IProductCatalog catalog)
{
    public Task<IReadOnlyList<Product>> ExecuteAsync(int? categoryId = null, CancellationToken cancellationToken = default) =>
        catalog.GetProductsAsync(categoryId, cancellationToken);
}
