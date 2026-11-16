using ECommerce.Domain.Categories;

namespace ECommerce.Application.Categories;

public sealed class GetCategories(ICategoryCatalog catalog)
{
    public Task<IReadOnlyList<Category>> ExecuteAsync(CancellationToken cancellationToken = default) =>
        catalog.GetCategoriesAsync(cancellationToken);
}
