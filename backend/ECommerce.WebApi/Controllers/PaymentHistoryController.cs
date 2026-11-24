using ECommerce.Application.Payments;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace ECommerce.WebApi.Controllers;

[ApiController]
[Route("api/payments/history")]
[Authorize]
public sealed class PaymentHistoryController(IPaymentAttemptStore attempts) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> List(CancellationToken ct)
    {
        if (!int.TryParse(User.FindFirst("partner_id")?.Value, out var partnerId) || partnerId <= 0) return Unauthorized();
        var history = await attempts.GetByPartnerAsync(partnerId, ct);
        return Ok(history.Select(attempt => new
        {
            attempt.OrderId,
            attempt.OrderName,
            attempt.AmountTotal,
            attempt.Currency,
            attempt.CreatedAt,
            attempt.Status
        }));
    }
}
