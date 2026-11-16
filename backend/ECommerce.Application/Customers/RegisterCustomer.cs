using ECommerce.Domain.Customers;

namespace ECommerce.Application.Customers;

public sealed class RegisterCustomer(ICustomerService customerService)
{
    public Task<Customer> ExecuteAsync(string name, string email, string password, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(name))
            throw new ArgumentException("El nombre del cliente es obligatorio.", nameof(name));

        if (string.IsNullOrWhiteSpace(email) || !email.Contains('@'))
            throw new ArgumentException("El correo electrónico no es válido.", nameof(email));

        if (string.IsNullOrWhiteSpace(password) || password.Length < 6)
            throw new ArgumentException("La contraseña debe tener al menos 6 caracteres.", nameof(password));

        return customerService.RegisterAsync(name.Trim(), email.Trim().ToLowerInvariant(), password, cancellationToken);
    }
}
