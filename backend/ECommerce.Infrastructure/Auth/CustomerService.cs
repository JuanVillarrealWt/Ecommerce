using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using ECommerce.Application.Customers;
using ECommerce.Application.Payments;
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

    public async Task<Customer> RegisterAsync(string name, string email, string password, string province, string phone, CancellationToken cancellationToken = default)
    {
        await _semaphore.WaitAsync(cancellationToken);
        try
        {
            var customers = await LoadCustomersAsync(cancellationToken);
            if (customers.Any(c => c.Email.Equals(email, StringComparison.OrdinalIgnoreCase)))
                throw new InvalidOperationException($"El correo '{email}' ya se encuentra registrado.");

            // 1. Obtener o crear el contacto en Odoo (res.partner)
            var partnerId = await GetOrCreateOdooPartnerAsync(name, email, cancellationToken, province, phone);

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
                PartnerId = partnerId,
                Province = province,
                Phone = phone
            };

            customers.Add(entity);
            await SaveCustomersAsync(customers, cancellationToken);

            return new Customer(entity.Id, entity.Name, entity.Email, entity.PartnerId, entity.Province, entity.Phone);
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

        // Sincronizar también cuentas antiguas; Odoo conserva el perfil compartido entre dispositivos.
        var realPartnerId = await GetOrCreateOdooPartnerAsync(
            customer.Name,
            customer.Email,
            cancellationToken,
            customer.Province,
            customer.Phone);
        if (customer.PartnerId != realPartnerId)
        {
            customer.PartnerId = realPartnerId;
            await SaveCustomersAsync(customers, cancellationToken);
            _logger.LogInformation("Partner de Odoo para {Email} actualizado a ID {PartnerId}.", customer.Email, realPartnerId);
        }

        var token = SimpleTokenService.GenerateToken(customer.Id, customer.Name, customer.Email, customer.PartnerId);
        var domainCustomer = new Customer(customer.Id, customer.Name, customer.Email, customer.PartnerId, customer.Province, customer.Phone);

        return (domainCustomer, token);
    }

    public async Task<Customer?> GetCustomerByIdAsync(int id, CancellationToken cancellationToken = default)
    {
        var customers = await LoadCustomersAsync(cancellationToken);
        var entity = customers.FirstOrDefault(c => c.Id == id);
        return entity is null ? null : new Customer(entity.Id, entity.Name, entity.Email, entity.PartnerId, entity.Province, entity.Phone);
    }

    public async Task<Customer> UpdateProfileAsync(int id, string name, string province, string phone, CancellationToken cancellationToken = default)
    {
        await _semaphore.WaitAsync(cancellationToken);
        try
        {
            var customers = await LoadCustomersAsync(cancellationToken);
            var entity = customers.FirstOrDefault(item => item.Id == id)
                ?? throw new KeyNotFoundException("No se encontró el perfil del cliente.");
            var partnerId = await GetOrCreateOdooPartnerAsync(name, entity.Email, cancellationToken, province, phone);
            entity.Name = name;
            entity.Province = province;
            entity.Phone = phone;
            entity.PartnerId = partnerId;
            await SaveCustomersAsync(customers, cancellationToken);
            return new Customer(entity.Id, entity.Name, entity.Email, entity.PartnerId, entity.Province, entity.Phone);
        }
        finally { _semaphore.Release(); }
    }

    public async Task UpdatePrimaryAddressAsync(int partnerId, string street, string city, string province, string postalCode, string phone, CancellationToken cancellationToken = default)
    {
        await _semaphore.WaitAsync(cancellationToken);
        try
        {
            var customers = await LoadCustomersAsync(cancellationToken);
            var entity = customers.FirstOrDefault(item => item.PartnerId == partnerId)
                ?? throw new KeyNotFoundException("No se encontró el perfil del cliente.");
            var synced = await GetOrCreateOdooPartnerAsync(entity.Name, entity.Email, cancellationToken, province, phone);
            if (synced != partnerId) throw new InvalidOperationException("El contacto de Odoo del cliente cambió; vuelve a iniciar sesión.");

            using var writeRequest = CreateOdooRequest(HttpMethod.Post, "/json/2/res.partner/write", new
            {
                ids = new[] { partnerId },
                vals = new Dictionary<string, object> { ["street"] = street, ["city"] = city, ["zip"] = postalCode, ["phone"] = phone }
            });
            using var writeResponse = await _http.SendAsync(writeRequest, cancellationToken);
            writeResponse.EnsureSuccessStatusCode();
            entity.Province = province;
            entity.Phone = phone;
            await SaveCustomersAsync(customers, cancellationToken);
        }
        finally { _semaphore.Release(); }
    }

    public async Task<PaymentCustomerProfile?> GetByPartnerIdAsync(int partnerId, CancellationToken cancellationToken = default)
    {
        await _semaphore.WaitAsync(cancellationToken);
        try
        {
            var customers = await LoadCustomersAsync(cancellationToken);
            var entity = customers.FirstOrDefault(customer => customer.PartnerId == partnerId);
            return entity is null
                ? null
                : new PaymentCustomerProfile(entity.PartnerId, entity.Name, entity.Email, entity.StripeCustomerId);
        }
        finally
        {
            _semaphore.Release();
        }
    }

    public async Task<string> SaveStripeCustomerIdIfMissingAsync(
        int partnerId,
        string stripeCustomerId,
        CancellationToken cancellationToken = default)
    {
        await _semaphore.WaitAsync(cancellationToken);
        try
        {
            var customers = await LoadCustomersAsync(cancellationToken);
            var entity = customers.FirstOrDefault(customer => customer.PartnerId == partnerId)
                ?? throw new InvalidOperationException("No se encontró el perfil del cliente autenticado.");

            if (!string.IsNullOrWhiteSpace(entity.StripeCustomerId)) return entity.StripeCustomerId;

            entity.StripeCustomerId = stripeCustomerId;
            await SaveCustomersAsync(customers, cancellationToken);
            return stripeCustomerId;
        }
        finally
        {
            _semaphore.Release();
        }
    }

    private static readonly JsonSerializerOptions OdooJsonOptions = new() { PropertyNamingPolicy = null };

    private HttpRequestMessage CreateOdooRequest<T>(HttpMethod method, string path, T content)
    {
        var request = new HttpRequestMessage(method, path);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _odooOptions.ApiKey);
        request.Headers.Add("X-Odoo-Database", _odooOptions.Database);
        var json = JsonSerializer.Serialize(content, content?.GetType() ?? typeof(T), OdooJsonOptions);
        request.Content = new StringContent(json, Encoding.UTF8, "application/json");
        return request;
    }

    private async Task<int> GetOrCreateOdooPartnerAsync(string name, string email, CancellationToken cancellationToken, string province, string phone)
    {
        try
        {
            if (string.IsNullOrWhiteSpace(_odooOptions.ApiKey) || string.IsNullOrWhiteSpace(_odooOptions.Database))
                throw new CustomerSyncException("Odoo no está configurado. Revisa la base de datos y la clave API antes de registrar o iniciar sesión.");

            using var countryRequest = CreateOdooRequest(HttpMethod.Post, "/json/2/res.country/search_read", new
            {
                domain = new object[] { new object[] { "code", "=", "EC" } },
                fields = new[] { "id", "name", "code" },
                limit = 1
            });
            using var countryResponse = await _http.SendAsync(countryRequest, cancellationToken);
            countryResponse.EnsureSuccessStatusCode();
            using var countryDoc = await JsonDocument.ParseAsync(await countryResponse.Content.ReadAsStreamAsync(cancellationToken), cancellationToken: cancellationToken);
            if (countryDoc.RootElement.ValueKind != JsonValueKind.Array || countryDoc.RootElement.GetArrayLength() == 0)
                throw new CustomerSyncException("Odoo no tiene configurado Ecuador en sus países.");
            var countryId = countryDoc.RootElement[0].GetProperty("id").GetInt32();

            using var stateRequest = CreateOdooRequest(HttpMethod.Post, "/json/2/res.country.state/search_read", new
            {
                domain = new object[] { new object[] { "country_id", "=", countryId }, new object[] { "name", "ilike", province } },
                fields = new[] { "id", "name" },
                limit = 30
            });
            using var stateResponse = await _http.SendAsync(stateRequest, cancellationToken);
            stateResponse.EnsureSuccessStatusCode();
            using var stateDoc = await JsonDocument.ParseAsync(await stateResponse.Content.ReadAsStreamAsync(cancellationToken), cancellationToken: cancellationToken);
            int? stateId = null;
            if (stateDoc.RootElement.ValueKind == JsonValueKind.Array)
                foreach (var candidate in stateDoc.RootElement.EnumerateArray())
                    if (candidate.TryGetProperty("name", out var stateName) && SameLocationName(stateName.GetString(), province))
                    {
                        stateId = candidate.GetProperty("id").GetInt32();
                        break;
                    }
            if (stateId is null)
                throw new CustomerSyncException($"Odoo no tiene registrada la provincia '{province}' para Ecuador. Agrégala en Contactos/Configuración y vuelve a intentar.");

            // 1. Buscar si ya existe por email
            using var searchRequest = CreateOdooRequest(HttpMethod.Post, "/json/2/res.partner/search_read", new
            {
                domain = new object[] { new object[] { "email", "ilike", email } },
                fields = new[] { "id", "name", "email" },
                limit = 50
            });

            using var searchResponse = await _http.SendAsync(searchRequest, cancellationToken);
            searchResponse.EnsureSuccessStatusCode();
            using (var searchDoc = await JsonDocument.ParseAsync(await searchResponse.Content.ReadAsStreamAsync(cancellationToken), cancellationToken: cancellationToken))
            {
                if (searchDoc.RootElement.ValueKind == JsonValueKind.Array)
                {
                    var foundPartner = searchDoc.RootElement.EnumerateArray().FirstOrDefault(candidate =>
                        candidate.TryGetProperty("email", out var partnerEmail) &&
                        string.Equals(partnerEmail.GetString(), email, StringComparison.OrdinalIgnoreCase));
                    if (foundPartner.ValueKind != JsonValueKind.Undefined)
                    {
                        var foundId = foundPartner.GetProperty("id").GetInt32();
                        var updateValues = new Dictionary<string, object>
                        {
                            ["name"] = name,
                            ["email"] = email,
                            ["phone"] = phone,
                            ["country_id"] = countryId,
                            ["state_id"] = stateId.Value,
                            ["customer_rank"] = 1,
                            ["active"] = true
                        };
                        using var updateRequest = CreateOdooRequest(HttpMethod.Post, "/json/2/res.partner/write", new { ids = new[] { foundId }, vals = updateValues });
                        using var updateResponse = await _http.SendAsync(updateRequest, cancellationToken);
                        updateResponse.EnsureSuccessStatusCode();
                        _logger.LogInformation("Contacto Odoo existente encontrado para {Email} con ID {Id}", email, foundId);
                        return foundId;
                    }
                }
            }

            // 2. Si no existe, crearlo con res.partner/create
            var partnerValues = new Dictionary<string, object>
            {
                ["name"] = name,
                ["email"] = email,
                ["active"] = true,
                ["customer_rank"] = 1,
                ["phone"] = phone
            };
            partnerValues["country_id"] = countryId;
            partnerValues["state_id"] = stateId.Value;
            using var createRequest = CreateOdooRequest(HttpMethod.Post, "/json/2/res.partner/create", new { vals_list = new[] { partnerValues } });

            using var createResponse = await _http.SendAsync(createRequest, cancellationToken);
            createResponse.EnsureSuccessStatusCode();
            using var createDoc = await JsonDocument.ParseAsync(await createResponse.Content.ReadAsStreamAsync(cancellationToken), cancellationToken: cancellationToken);
            if (createDoc.RootElement.ValueKind != JsonValueKind.Array || createDoc.RootElement.GetArrayLength() == 0)
                throw new CustomerSyncException("Odoo respondió sin confirmar la creación del contacto.");
            var newId = createDoc.RootElement[0].GetInt32();
            _logger.LogInformation("Nuevo contacto Odoo creado para {Email} con ID {Id}", email, newId);
            return newId;
        }
        catch (CustomerSyncException)
        {
            throw;
        }
        catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            throw new CustomerSyncException("Odoo tardó demasiado en responder. Intenta nuevamente.");
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (HttpRequestException ex)
        {
            _logger.LogError(ex, "Fallo la sincronización del contacto {Email} con Odoo.", email);
            throw new CustomerSyncException("No se pudo conectar con Odoo. No se creó la cuenta; verifica que Odoo esté disponible e intenta nuevamente.", ex);
        }
        catch (Exception ex) when (ex is JsonException or InvalidOperationException or KeyNotFoundException)
        {
            _logger.LogError(ex, "Odoo devolvió una respuesta inesperada al sincronizar {Email}.", email);
            throw new CustomerSyncException("Odoo devolvió una respuesta inesperada. No se creó la cuenta; revisa la integración e intenta nuevamente.", ex);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "No se pudo sincronizar el cliente {Email} con Odoo.", email);
            throw new CustomerSyncException("No se pudo guardar el cliente en Odoo. No se creó la cuenta.", ex);
        }
    }

    private static bool SameLocationName(string? actual, string expected)
    {
        static string Normalize(string? value) => string.Concat((value ?? string.Empty)
            .Normalize(NormalizationForm.FormD)
            .Where(character => System.Globalization.CharUnicodeInfo.GetUnicodeCategory(character) != System.Globalization.UnicodeCategory.NonSpacingMark))
            .Trim()
            .ToLowerInvariant();
        return Normalize(actual) == Normalize(expected);
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
