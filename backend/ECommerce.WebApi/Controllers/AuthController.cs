using ECommerce.Application.Customers;
using ECommerce.WebApi.Contracts;
using Microsoft.AspNetCore.Mvc;

namespace ECommerce.WebApi.Controllers;

[ApiController]
[Route("api/auth")]
public sealed class AuthController(RegisterCustomer registerCustomer, LoginCustomer loginCustomer) : ControllerBase
{
    [HttpPost("register")]
    [ProducesResponseType<CustomerDto>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<CustomerDto>> Register([FromBody] RegisterRequest request, CancellationToken cancellationToken)
    {
        try
        {
            var customer = await registerCustomer.ExecuteAsync(request.Name, request.Email, request.Password, cancellationToken);
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
    }
}
