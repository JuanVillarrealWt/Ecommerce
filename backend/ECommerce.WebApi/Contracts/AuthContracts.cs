using ECommerce.Domain.Customers;

namespace ECommerce.WebApi.Contracts;

public sealed record RegisterRequest(string Name, string Email, string Password);

public sealed record LoginRequest(string Email, string Password);

public sealed record CustomerDto(int Id, string Name, string Email, int PartnerId)
{
    public static CustomerDto From(Customer c) => new(c.Id, c.Name, c.Email, c.PartnerId);
}

public sealed record AuthResponse(string Token, CustomerDto Customer);
