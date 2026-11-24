using ECommerce.Application.Payments;
using ECommerce.Application.CustomerFeatures;
using ECommerce.WebApi.Contracts;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Text.Json;

namespace ECommerce.WebApi.Controllers;

[ApiController]
[Route("api/checkout")]
public sealed class CheckoutController(
    StartCheckout startCheckout,
    PrepareCheckoutConfirmation prepareCheckoutConfirmation,
    ProcessPaymentWebhook processPaymentWebhook,
    IPaymentGateway paymentGateway,
    IPaymentAttemptStore paymentAttemptStore,
    ManageCustomerFeatures customerFeatures) : ControllerBase
{
    [Authorize]
    [HttpPost("payments")]
    [ProducesResponseType<CheckoutResponse>(StatusCodes.Status201Created)]
    public async Task<ActionResult<CheckoutResponse>> Start(
        [FromBody] CreateOrderApiRequest request,
        CancellationToken cancellationToken)
    {
        var partnerId = GetAuthenticatedPartnerId();
        try
        {
            var customerData = await customerFeatures.GetAsync(partnerId, cancellationToken);
            SavedAddress? selectedAddress = null;
            if (request.SavedAddressId is Guid requestedAddressId)
            {
                selectedAddress = customerData.Addresses
                    .FirstOrDefault(address => address.Id == requestedAddressId);
                if (selectedAddress is null)
                {
                    return BadRequest(new ProblemDetails
                    {
                        Title = "Dirección inválida",
                        Detail = "La dirección seleccionada no pertenece a tu cuenta.",
                        Status = StatusCodes.Status400BadRequest
                    });
                }
            }
            else
            {
                selectedAddress = customerData.Addresses.FirstOrDefault(address => address.IsDefault);
            }

            var items = request.Items.Select(item => new ECommerce.Application.Orders.CreateOrderItemRequest(item.ProductId, item.Quantity)).ToArray();
            var deliveryAddress = selectedAddress is null ? null : new ECommerce.Application.Orders.OrderDeliveryAddress(
                selectedAddress.Label,
                selectedAddress.Recipient,
                selectedAddress.Street,
                selectedAddress.City,
                selectedAddress.Province,
                selectedAddress.PostalCode,
                selectedAddress.Phone);
            var result = await startCheckout.ExecuteAsync(
                partnerId, items, request.CouponCode, deliveryAddress, cancellationToken);
            return StatusCode(StatusCodes.Status201Created, new CheckoutResponse(
                result.AttemptId, result.ClientSecret, result.CustomerId,
                result.CustomerSessionClientSecret, result.OrderName, result.AmountTotal, result.Currency));
        }
        catch (ArgumentException ex)
        {
            return BadRequest(new ProblemDetails { Title = "Solicitud inválida", Detail = ex.Message, Status = StatusCodes.Status400BadRequest });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new ProblemDetails { Title = "No se pudo iniciar el pago", Detail = ex.Message, Status = StatusCodes.Status400BadRequest });
        }
    }

    [Authorize]
    [HttpPost("payments/{attemptId}/confirmation")]
    public async Task<ActionResult<PrepareCheckoutConfirmationResponse>> PrepareConfirmation(
        string attemptId,
        CancellationToken cancellationToken)
    {
        try
        {
            var clientSecret = await prepareCheckoutConfirmation.ExecuteAsync(
                GetAuthenticatedPartnerId(), attemptId, cancellationToken);
            return Ok(new PrepareCheckoutConfirmationResponse(clientSecret));
        }
        catch (KeyNotFoundException)
        {
            return NotFound();
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new ProblemDetails { Title = "No se pudo preparar el pago", Detail = ex.Message, Status = StatusCodes.Status400BadRequest });
        }
    }

    [Authorize]
    [HttpGet("payments/{attemptId}")]
    [ProducesResponseType<CheckoutStatusResponse>(StatusCodes.Status200OK)]
    public async Task<ActionResult<CheckoutStatusResponse>> Status(string attemptId, CancellationToken cancellationToken)
    {
        var attempt = await paymentAttemptStore.GetAsync(attemptId, cancellationToken);
        if (attempt is null || attempt.PartnerId != GetAuthenticatedPartnerId()) return NotFound();
        return Ok(new CheckoutStatusResponse(
            attempt.Id, attempt.OrderName, attempt.AmountTotal, attempt.Currency, attempt.Status));
    }

    [AllowAnonymous]
    [HttpPost("webhook")]
    public async Task<IActionResult> Webhook(CancellationToken cancellationToken)
    {
        using var reader = new StreamReader(Request.Body);
        var payload = await reader.ReadToEndAsync(cancellationToken);
        var signature = Request.Headers["Stripe-Signature"].FirstOrDefault();
        if (string.IsNullOrWhiteSpace(signature)) return BadRequest();

        PaymentWebhookNotification notification;
        try { notification = paymentGateway.VerifyWebhook(payload, signature); }
        catch (UnauthorizedAccessException) { return BadRequest(); }
        catch (JsonException) { return BadRequest(); }

        await processPaymentWebhook.ExecuteAsync(notification, cancellationToken);
        return Ok();
    }

    private int GetAuthenticatedPartnerId()
    {
        var claim = User.FindFirst("partner_id")?.Value;
        if (int.TryParse(claim, out var partnerId) && partnerId > 0) return partnerId;
        throw new UnauthorizedAccessException("El token no contiene un partner_id válido.");
    }
}
