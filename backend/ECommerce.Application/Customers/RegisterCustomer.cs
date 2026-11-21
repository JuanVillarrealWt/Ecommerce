using ECommerce.Domain.Customers;
using System.Text.RegularExpressions;

namespace ECommerce.Application.Customers;

public sealed class RegisterCustomer(ICustomerService customerService)
{
    public Task<Customer> ExecuteAsync(string name, string email, string password, string province, string phone, CancellationToken cancellationToken = default)
    {
        name = name?.Trim() ?? string.Empty;
        email = email?.Trim() ?? string.Empty;
        province = province?.Trim() ?? string.Empty;
        phone = phone?.Trim() ?? string.Empty;

        if (name.Length is 0 or > 50 || !Regex.IsMatch(name, @"^[\p{L}]+(?:[ '-][\p{L}]+)*$"))
            throw new ArgumentException("El nombre es obligatorio, admite hasta 50 caracteres y solo letras, espacios, guion o apóstrofo.", nameof(name));

        if (email.Length > 50 || email.Contains("  ") || !Regex.IsMatch(email, @"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$"))
            throw new ArgumentException("El correo electrónico no es válido.", nameof(email));

        if (string.IsNullOrEmpty(password) || password.Length < 8 || password.Length > 50 ||
            Regex.IsMatch(password, @"\s") ||
            !Regex.IsMatch(password, @"[A-Z]") || !Regex.IsMatch(password, @"[a-z]") ||
            !Regex.IsMatch(password, @"\d") || !Regex.IsMatch(password, @"[^A-Za-z0-9]"))
            throw new ArgumentException("La contraseña debe tener 8–50 caracteres, mayúscula, minúscula, número y símbolo, sin espacios.", nameof(password));

        var provinces = new[] { "Azuay", "Bolívar", "Cañar", "Carchi", "Chimborazo", "Cotopaxi", "El Oro", "Esmeraldas", "Galápagos", "Guayas", "Imbabura", "Loja", "Los Ríos", "Manabí", "Morona Santiago", "Napo", "Orellana", "Pastaza", "Pichincha", "Santa Elena", "Santo Domingo de los Tsáchilas", "Sucumbíos", "Tungurahua", "Zamora Chinchipe" };
        if (!provinces.Contains(province, StringComparer.OrdinalIgnoreCase))
            throw new ArgumentException("Selecciona una provincia válida del Ecuador.", nameof(province));
        if (!Regex.IsMatch(phone, @"^09\d{8}$"))
            throw new ArgumentException("El celular debe tener 10 dígitos y comenzar con 09.", nameof(phone));

        return customerService.RegisterAsync(name, email.ToLowerInvariant(), password, province, phone, cancellationToken);
    }
}

