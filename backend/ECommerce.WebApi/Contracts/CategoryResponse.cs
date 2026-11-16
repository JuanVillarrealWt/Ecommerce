using ECommerce.Domain.Categories;

namespace ECommerce.WebApi.Contracts;

public sealed record CategoryResponse(int Id, string Name, int? ParentId)
{
    public static CategoryResponse From(Category c) => new(c.Id, c.Name, c.ParentId);
}
