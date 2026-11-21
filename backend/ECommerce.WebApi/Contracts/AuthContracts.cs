using ECommerce.Domain.Customers;

namespace ECommerce.WebApi.Contracts;

public sealed record RegisterRequest(string Name, string Email, string Password, string Province, string Phone);

public sealed record LoginRequest(string Email, string Password);

public sealed record CustomerDto(int Id, string Name, string Email, int PartnerId, string Province, string Phone)
{
    public static CustomerDto From(Customer c) => new(c.Id, c.Name, c.Email, c.PartnerId, c.Province, c.Phone);
}

public sealed record AuthResponse(string Token, CustomerDto Customer);

