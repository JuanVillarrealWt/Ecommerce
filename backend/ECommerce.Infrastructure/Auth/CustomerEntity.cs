namespace ECommerce.Infrastructure.Auth;

public sealed class CustomerEntity
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string PasswordHash { get; set; } = string.Empty;
    public string Salt { get; set; } = string.Empty;
    public int PartnerId { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
