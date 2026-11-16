using ECommerce.Domain.Products;

namespace ECommerce.Application.Products;

public sealed class GetProduct(IProductCatalog catalog)
{
    public Task<Product?> ExecuteAsync(int id, CancellationToken cancellationToken = default) =>
        id <= 0 ? Task.FromResult<Product?>(null) : catalog.GetProductAsync(id, cancellationToken);
}
