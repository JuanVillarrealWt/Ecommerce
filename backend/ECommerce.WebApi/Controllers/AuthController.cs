using ECommerce.Application.Customers;
using ECommerce.Application.Orders;
using ECommerce.Application.CustomerFeatures;
using ECommerce.WebApi.Contracts;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace ECommerce.WebApi.Controllers;

[ApiController]
[Route("api/auth")]
public sealed class AuthController(
    RegisterCustomer registerCustomer,
    LoginCustomer loginCustomer,
    ICustomerService customers,
    IOrderService orders,
    IOrderSnapshotStore orderSnapshots,
    ManageCustomerFeatures customerFeatures) : ControllerBase
{
    [HttpPost("register")]
    [ProducesResponseType<CustomerDto>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<CustomerDto>> Register([FromBody] RegisterRequest request, CancellationToken cancellationToken)
    {
        try
        {
            var customer = await registerCustomer.ExecuteAsync(request.Name, request.Email, request.Password, request.Province, request.Phone, cancellationToken);
            return Ok(CustomerDto.From(customer));
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new ProblemDetails { Title = "Datos inválidos", Detail = ex.Message, Status = StatusCodes.Status400BadRequest });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new ProblemDetails { Title = "Operación no permitida", Detail = ex.Message, Status = StatusCodes.Status400BadRequest });
        }
        catch (CustomerSyncException ex)
        {
            return StatusCode(StatusCodes.Status503ServiceUnavailable, new ProblemDetails { Title = "No se pudo sincronizar con Odoo", Detail = ex.Message, Status = StatusCodes.Status503ServiceUnavailable });
        }
    }

    [HttpPost("login")]
    [ProducesResponseType<AuthResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<AuthResponse>> Login([FromBody] LoginRequest request, CancellationToken cancellationToken)
    {
        try
        {
            var (customer, token) = await loginCustomer.ExecuteAsync(request.Email, request.Password, cancellationToken);
            return Ok(new AuthResponse(token, CustomerDto.From(customer)));
        }
        catch (UnauthorizedAccessException ex)
        {
            return Unauthorized(new ProblemDetails { Title = "No autorizado", Detail = ex.Message, Status = StatusCodes.Status401Unauthorized });
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new ProblemDetails { Title = "Datos inválidos", Detail = ex.Message, Status = StatusCodes.Status400BadRequest });
        }
        catch (CustomerSyncException ex)
        {
            return StatusCode(StatusCodes.Status503ServiceUnavailable, new ProblemDetails { Title = "No se pudo sincronizar con Odoo", Detail = ex.Message, Status = StatusCodes.Status503ServiceUnavailable });
        }
    }

    [Authorize]
    [HttpPut("profile")]
    public async Task<ActionResult<CustomerDto>> UpdateProfile([FromBody] UpdateProfileRequest request, CancellationToken cancellationToken)
    {
        if (!int.TryParse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value, out var customerId)) return Unauthorized();
        var name = request.Name?.Trim() ?? string.Empty;
        var province = request.Province?.Trim() ?? string.Empty;
        var phone = request.Phone?.Trim() ?? string.Empty;
        var nameParts = name.Split(' ', StringSplitOptions.RemoveEmptyEntries);
        if (name.Length is < 3 or > 101 || nameParts.Any(part => part.Length > 50) || !System.Text.RegularExpressions.Regex.IsMatch(name, @"^[\p{L}]+(?:[ '-][\p{L}]+)*$") || name.Contains("  ")) return BadRequest(new ProblemDetails { Title = "Nombre inválido", Detail = "Nombre y apellido admiten hasta 50 caracteres cada uno." });
        if (!System.Text.RegularExpressions.Regex.IsMatch(phone, @"^09\d{8}$")) return BadRequest(new ProblemDetails { Title = "Teléfono inválido", Detail = "El celular debe tener 10 dígitos y comenzar con 09." });
        try
        {
            var tokenName = User.FindFirst(ClaimTypes.Name)?.Value;
            if (!string.Equals(tokenName, name, StringComparison.Ordinal))
            {
                if (!int.TryParse(User.FindFirst("partner_id")?.Value, out var partnerId) || partnerId <= 0)
                    return Unauthorized();
                var ordersToPreserve = await orders.GetCustomerOrdersAsync(partnerId, cancellationToken);
                foreach (var summary in ordersToPreserve)
                {
                    if (await orderSnapshots.GetAsync(summary.Id, cancellationToken) is not null)
                        continue;
                    var detail = await orders.GetOrderByIdAsync(summary.Id, cancellationToken);
                    if (detail is not null)
                        await orderSnapshots.CaptureIfMissingAsync(detail, cancellationToken);
                }
            }

            var updated = await customers.UpdateProfileAsync(customerId, name, province, phone, cancellationToken);
            await customerFeatures.UpdateAsync(updated.PartnerId, data =>
            {
                var index = data.Addresses.FindIndex(address => address.IsDefault);
                if (index >= 0)
                    data.Addresses[index] = data.Addresses[index] with
                    {
                        Province = province,
                        Phone = phone
                    };
            }, cancellationToken);
            return Ok(CustomerDto.From(updated));
        }
        catch (KeyNotFoundException ex) { return NotFound(new ProblemDetails { Title = "Perfil no encontrado", Detail = ex.Message }); }
        catch (CustomerSyncException ex) { return StatusCode(StatusCodes.Status503ServiceUnavailable, new ProblemDetails { Title = "No se pudo sincronizar con Odoo", Detail = ex.Message }); }
    }
}

