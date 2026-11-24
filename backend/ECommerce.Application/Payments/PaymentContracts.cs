namespace ECommerce.Application.Payments;

public sealed record PaymentIntentCredentials(string PaymentIntentId, string ClientSecret);

public sealed record StripeCustomerCredentials(string CustomerId);

public sealed record StripeCustomerSessionCredentials(string ClientSecret);

public sealed record PaymentCustomerProfile(int PartnerId, string Name, string Email, string? StripeCustomerId);

public sealed record PaymentWebhookNotification(string EventId, string EventType, string PaymentIntentId, string? AttemptId);

public sealed record PaymentAttempt(
    string Id,
    int PartnerId,
    int OrderId,
    string OrderName,
    decimal AmountTotal,
    string Currency,
    string Status,
    string? PaymentIntentId,
    DateTime CreatedAt);

public sealed record CheckoutStarted(
    string AttemptId,
    string ClientSecret,
    string CustomerId,
    string CustomerSessionClientSecret,
    string OrderName,
    decimal AmountTotal,
    string Currency);

public sealed record CheckoutStatus(
    string AttemptId,
    string OrderName,
    decimal AmountTotal,
    string Currency,
    string Status);

public sealed class DiscountCoupon
{
    public string Code { get; set; } = string.Empty;
    public decimal Percentage { get; set; }
    public List<int> ProductIds { get; set; } = [];
}

public interface IPaymentGateway
{
    Task<StripeCustomerCredentials> CreateCustomerAsync(
        string name,
        string email,
        int partnerId,
        CancellationToken cancellationToken = default);

    Task<StripeCustomerSessionCredentials> CreateCustomerSessionAsync(
        string customerId,
        CancellationToken cancellationToken = default);

    Task<string> UpdatePaymentIntentSavePreferenceAsync(
        string paymentIntentId,
        CancellationToken cancellationToken = default);

    Task<PaymentIntentCredentials> CreatePaymentIntentAsync(
        long amountMinor,
        string currency,
        string attemptId,
        int orderId,
        string customerId,
        CancellationToken cancellationToken = default);

    PaymentWebhookNotification VerifyWebhook(string payload, string signature);
}

public interface IPaymentCustomerProfileStore
{
    Task<PaymentCustomerProfile?> GetByPartnerIdAsync(
        int partnerId,
        CancellationToken cancellationToken = default);

    Task<string> SaveStripeCustomerIdIfMissingAsync(
        int partnerId,
        string stripeCustomerId,
        CancellationToken cancellationToken = default);
}

public interface IPaymentAttemptStore
{
    Task AddAsync(PaymentAttempt attempt, CancellationToken cancellationToken = default);
    Task<PaymentAttempt?> GetAsync(string attemptId, CancellationToken cancellationToken = default);
    Task<PaymentAttempt?> FindByPaymentIntentAsync(string paymentIntentId, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<PaymentAttempt>> GetByPartnerAsync(int partnerId, CancellationToken cancellationToken = default);
    Task UpdateAsync(PaymentAttempt attempt, CancellationToken cancellationToken = default);
}
