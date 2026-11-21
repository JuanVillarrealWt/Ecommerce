namespace ECommerce.Domain.Categories;

public sealed class Category(int id, string name, int? parentId = null)
{
    public int Id { get; } = id;
    public string Name { get; } = name;
    public int? ParentId { get; } = parentId;
}

