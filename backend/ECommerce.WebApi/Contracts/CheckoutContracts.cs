namespace ECommerce.WebApi.Contracts;

public sealed record CheckoutResponse(
    string AttemptId,
    string ClientSecret,
    string CustomerId,
    string CustomerSessionClientSecret,
    string OrderName,
    decimal AmountTotal,
    string Currency);

public sealed record CheckoutStatusResponse(
    string AttemptId,
    string OrderName,
    decimal AmountTotal,
    string Currency,
    string Status);

public sealed record PrepareCheckoutConfirmationResponse(string ClientSecret);
