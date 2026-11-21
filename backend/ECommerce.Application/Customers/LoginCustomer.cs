using ECommerce.Domain.Customers;
using System.Text.RegularExpressions;

namespace ECommerce.Application.Customers;

public sealed class LoginCustomer(ICustomerService customerService)
{
    public Task<(Customer Customer, string Token)> ExecuteAsync(string email, string password, CancellationToken cancellationToken = default)
    {
        email = email?.Trim() ?? string.Empty;
        if (email.Length is 0 or > 50 || email.Contains("  ") ||
            !Regex.IsMatch(email, @"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$"))
            throw new ArgumentException("El correo electrónico no es válido (máximo 50 caracteres).", nameof(email));

        if (string.IsNullOrEmpty(password) || password.Length > 50 || password.Contains("  "))
            throw new ArgumentException("La contraseña es obligatoria, admite máximo 50 caracteres y no permite espacios repetidos.", nameof(password));

        return customerService.LoginAsync(email.ToLowerInvariant(), password, cancellationToken);
    }
}

