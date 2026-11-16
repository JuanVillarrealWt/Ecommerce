using ECommerce.Domain.Categories;

namespace ECommerce.Application.Categories;

public interface ICategoryCatalog
{
    Task<IReadOnlyList<Category>> GetCategoriesAsync(CancellationToken cancellationToken = default);
}
