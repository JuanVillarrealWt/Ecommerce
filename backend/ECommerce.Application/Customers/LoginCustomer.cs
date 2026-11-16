using ECommerce.Domain.Customers;

namespace ECommerce.Application.Customers;

public sealed class LoginCustomer(ICustomerService customerService)
{
    public Task<(Customer Customer, string Token)> ExecuteAsync(string email, string password, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(email))
            throw new ArgumentException("El correo electrónico es obligatorio.", nameof(email));

        if (string.IsNullOrWhiteSpace(password))
            throw new ArgumentException("La contraseña es obligatoria.", nameof(password));

        return customerService.LoginAsync(email.Trim().ToLowerInvariant(), password, cancellationToken);
    }
}
