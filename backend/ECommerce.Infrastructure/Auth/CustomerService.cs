using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using ECommerce.Application.Customers;
using ECommerce.Domain.Customers;
using ECommerce.Infrastructure.Odoo;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace ECommerce.Infrastructure.Auth;

public sealed class CustomerService : ICustomerService
{
    private readonly HttpClient _http;
    private readonly OdooOptions _odooOptions;
    private readonly ILogger<CustomerService> _logger;
    private readonly string _storagePath;
    private readonly SemaphoreSlim _semaphore = new(1, 1);
    private List<CustomerEntity>? _cache;

    public CustomerService(
        HttpClient http,
        IOptions<OdooOptions> odooOptions,
        IHostEnvironment env,
        ILogger<CustomerService> logger)
    {
        _http = http;
        _odooOptions = odooOptions.Value;
        _logger = logger;
        _storagePath = Path.Combine(env.ContentRootPath, "customers.json");
    }

    public async Task<Customer> RegisterAsync(string name, string email, string password, CancellationToken cancellationToken = default)
    {
        await _semaphore.WaitAsync(cancellationToken);
        try
        {
            var customers = await LoadCustomersAsync(cancellationToken);
            if (customers.Any(c => c.Email.Equals(email, StringComparison.OrdinalIgnoreCase)))
                throw new InvalidOperationException($"El correo '{email}' ya se encuentra registrado.");

            // 1. Obtener o crear el contacto en Odoo (res.partner)
            var partnerId = await GetOrCreateOdooPartnerAsync(name, email, cancellationToken);

            // 2. Hashear contraseña con PBKDF2
            var salt = GenerateSalt();
            var passwordHash = HashPassword(password, salt);

            var nextId = customers.Count > 0 ? customers.Max(c => c.Id) + 1 : 1;
            var entity = new CustomerEntity
            {
                Id = nextId,
                Name = name,
                Email = email,
                PasswordHash = passwordHash,
                Salt = salt,
                PartnerId = partnerId
            };

            customers.Add(entity);
            await SaveCustomersAsync(customers, cancellationToken);

            return new Customer(entity.Id, entity.Name, entity.Email, entity.PartnerId);
        }
        finally
        {
            _semaphore.Release();
        }
    }

    public async Task<(Customer Customer, string Token)> LoginAsync(string email, string password, CancellationToken cancellationToken = default)
    {
        var customers = await LoadCustomersAsync(cancellationToken);
        var customer = customers.FirstOrDefault(c => c.Email.Equals(email, StringComparison.OrdinalIgnoreCase));

        if (customer is null || !VerifyPassword(password, customer.Salt, customer.PasswordHash))
            throw new UnauthorizedAccessException("Credenciales incorrectas.");

        var token = SimpleTokenService.GenerateToken(customer.Id, customer.Name, customer.Email, customer.PartnerId);
        var domainCustomer = new Customer(customer.Id, customer.Name, customer.Email, customer.PartnerId);

        return (domainCustomer, token);
    }

    public async Task<Customer?> GetCustomerByIdAsync(int id, CancellationToken cancellationToken = default)
    {
        var customers = await LoadCustomersAsync(cancellationToken);
        var entity = customers.FirstOrDefault(c => c.Id == id);
        return entity is null ? null : new Customer(entity.Id, entity.Name, entity.Email, entity.PartnerId);
    }

    private async Task<int> GetOrCreateOdooPartnerAsync(string name, string email, CancellationToken cancellationToken)
    {
        try
        {
            if (string.IsNullOrWhiteSpace(_odooOptions.ApiKey) || string.IsNullOrWhiteSpace(_odooOptions.Database))
                return 6; // Partner de prueba por defecto si Odoo no está configurado (Consumidor final del PDF)

            // Buscar si ya existe
            using var searchRequest = new HttpRequestMessage(HttpMethod.Post, "/json/2/res.partner/search_read");
            searchRequest.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _odooOptions.ApiKey);
            searchRequest.Headers.Add("X-Odoo-Database", _odooOptions.Database);
            searchRequest.Content = JsonContent.Create(new
            {
                domain = new object[] { new object[] { "email", "=", email } },
                fields = new[] { "id", "name" },
                limit = 1
            });

            using var searchResponse = await _http.SendAsync(searchRequest, cancellationToken);
            if (searchResponse.IsSuccessStatusCode)
            {
                using var searchDoc = await JsonDocument.ParseAsync(await searchResponse.Content.ReadAsStreamAsync(cancellationToken), cancellationToken: cancellationToken);
                if (searchDoc.RootElement.ValueKind == JsonValueKind.Array && searchDoc.RootElement.GetArrayLength() > 0)
                {
                    return searchDoc.RootElement[0].GetProperty("id").GetInt32();
                }
            }

            // Si no existe, crearlo
            using var createRequest = new HttpRequestMessage(HttpMethod.Post, "/json/2/res.partner/create");
            createRequest.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _odooOptions.ApiKey);
            createRequest.Headers.Add("X-Odoo-Database", _odooOptions.Database);
            createRequest.Content = JsonContent.Create(new
            {
                vals_list = new[]
                {
                    new Dictionary<string, object>
                    {
                        ["name"] = name,
                        ["email"] = email,
                        ["active"] = true,
                        ["customer_rank"] = 1
                    }
                }
            });

            using var createResponse = await _http.SendAsync(createRequest, cancellationToken);
            if (createResponse.IsSuccessStatusCode)
            {
                using var createDoc = await JsonDocument.ParseAsync(await createResponse.Content.ReadAsStreamAsync(cancellationToken), cancellationToken: cancellationToken);
                if (createDoc.RootElement.ValueKind == JsonValueKind.Array && createDoc.RootElement.GetArrayLength() > 0)
                {
                    return createDoc.RootElement[0].GetInt32();
                }
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "No se pudo sincronizar el cliente con Odoo; se asignará ID de contacto local.");
        }

        return 6; // Consumidor final por defecto según PDF
    }

    private async Task<List<CustomerEntity>> LoadCustomersAsync(CancellationToken cancellationToken)
    {
        if (_cache != null) return _cache;

        if (!File.Exists(_storagePath))
        {
            _cache = new List<CustomerEntity>();
            return _cache;
        }

        var json = await File.ReadAllTextAsync(_storagePath, cancellationToken);
        _cache = JsonSerializer.Deserialize<List<CustomerEntity>>(json) ?? new List<CustomerEntity>();
        return _cache;
    }

    private async Task SaveCustomersAsync(List<CustomerEntity> list, CancellationToken cancellationToken)
    {
        _cache = list;
        var json = JsonSerializer.Serialize(list, new JsonSerializerOptions { WriteIndented = true });
        await File.WriteAllTextAsync(_storagePath, json, cancellationToken);
    }

    private static string GenerateSalt()
    {
        var bytes = new byte[16];
        using var rng = RandomNumberGenerator.Create();
        rng.GetBytes(bytes);
        return Convert.ToBase64String(bytes);
    }

    private static string HashPassword(string password, string salt)
    {
        var saltBytes = Convert.FromBase64String(salt);
        var hashBytes = Rfc2898DeriveBytes.Pbkdf2(
            password,
            saltBytes,
            10000,
            HashAlgorithmName.SHA256,
            32);
        return Convert.ToBase64String(hashBytes);
    }

    private static bool VerifyPassword(string password, string salt, string hash)
    {
        var computed = HashPassword(password, salt);
        return CryptographicOperations.FixedTimeEquals(
            Encoding.UTF8.GetBytes(computed),
            Encoding.UTF8.GetBytes(hash));
    }
}
