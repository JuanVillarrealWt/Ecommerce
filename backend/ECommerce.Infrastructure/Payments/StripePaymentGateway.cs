using System.Globalization;
using System.Net.Http.Headers;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using ECommerce.Application.Payments;
using Microsoft.Extensions.Options;

namespace ECommerce.Infrastructure.Payments;

public sealed class StripePaymentGateway(
    HttpClient http,
    IOptions<StripePaymentOptions> options) : IPaymentGateway
{
    private readonly StripePaymentOptions _options = options.Value;

    public async Task<StripeCustomerCredentials> CreateCustomerAsync(
        string name,
        string email,
        int partnerId,
        CancellationToken cancellationToken = default)
    {
        using var json = await SendStripeFormAsync(
            "customers",
            new Dictionary<string, string>
            {
                ["name"] = name,
                ["email"] = email,
                ["metadata[partner_id]"] = partnerId.ToString(CultureInfo.InvariantCulture)
            },
            $"entre-cumbres-customer-{partnerId}",
            cancellationToken);

        return new StripeCustomerCredentials(json.RootElement.GetProperty("id").GetString()!);
    }

    public async Task<StripeCustomerSessionCredentials> CreateCustomerSessionAsync(
        string customerId,
        CancellationToken cancellationToken = default)
    {
        using var json = await SendStripeFormAsync(
            "customer_sessions",
            new Dictionary<string, string>
            {
                ["customer"] = customerId,
                ["components[mobile_payment_element][enabled]"] = "true",
                ["components[mobile_payment_element][features][payment_method_save]"] = "enabled",
                ["components[mobile_payment_element][features][payment_method_redisplay]"] = "enabled",
                ["components[mobile_payment_element][features][payment_method_remove]"] = "enabled",
                ["components[payment_element][enabled]"] = "true",
                ["components[payment_element][features][payment_method_save]"] = "enabled",
                ["components[payment_element][features][payment_method_redisplay]"] = "enabled",
                ["components[payment_element][features][payment_method_remove]"] = "enabled"
            },
            null,
            cancellationToken);

        return new StripeCustomerSessionCredentials(
            json.RootElement.GetProperty("client_secret").GetString()!);
    }

    public async Task<string> UpdatePaymentIntentSavePreferenceAsync(
        string paymentIntentId,
        CancellationToken cancellationToken = default)
    {
        using var json = await SendStripeFormAsync(
            $"payment_intents/{Uri.EscapeDataString(paymentIntentId)}",
            new Dictionary<string, string>
            {
                ["setup_future_usage"] = "off_session"
            },
            null,
            cancellationToken);

        return json.RootElement.GetProperty("client_secret").GetString()!;
    }

    public async Task<PaymentIntentCredentials> CreatePaymentIntentAsync(
        long amountMinor,
        string currency,
        string attemptId,
        int orderId,
        string customerId,
        CancellationToken cancellationToken = default)
    {
        using var json = await SendStripeFormAsync(
            "payment_intents",
            new Dictionary<string, string>
        {
            ["amount"] = amountMinor.ToString(CultureInfo.InvariantCulture),
            ["currency"] = currency,
            ["customer"] = customerId,
            ["setup_future_usage"] = "off_session",
            ["allowed_payment_method_types[]"] = "card",
            ["metadata[checkout_attempt_id]"] = attemptId,
            ["metadata[odoo_order_id]"] = orderId.ToString(CultureInfo.InvariantCulture)
        },
            $"entre-cumbres-{attemptId}",
            cancellationToken);

        return new PaymentIntentCredentials(
            json.RootElement.GetProperty("id").GetString()!,
            json.RootElement.GetProperty("client_secret").GetString()!);
    }

    private async Task<JsonDocument> SendStripeFormAsync(
        string endpoint,
        Dictionary<string, string> values,
        string? idempotencyKey,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(_options.SecretKey))
            throw new InvalidOperationException("Stripe no está configurado. Define Stripe__SecretKey en el entorno del backend.");

        using var request = new HttpRequestMessage(HttpMethod.Post, $"https://api.stripe.com/v1/{endpoint}");
        request.Headers.Authorization = new AuthenticationHeaderValue(
            "Basic", Convert.ToBase64String(Encoding.UTF8.GetBytes(_options.SecretKey + ":")));
        if (!string.IsNullOrWhiteSpace(idempotencyKey))
            request.Headers.Add("Idempotency-Key", idempotencyKey);
        request.Content = new FormUrlEncodedContent(values);

        using var response = await http.SendAsync(request, cancellationToken);
        var responseBody = await response.Content.ReadAsStringAsync(cancellationToken);
        if (!response.IsSuccessStatusCode)
        {
            var stripeMessage = "Revisa la configuración de la cuenta.";
            try
            {
                using var errorJson = JsonDocument.Parse(responseBody);
                stripeMessage = errorJson.RootElement.GetProperty("error").GetProperty("message").GetString()
                    ?? stripeMessage;
            }
            catch (JsonException) { }

            throw new InvalidOperationException(
                $"Stripe rechazó la solicitud ({(int)response.StatusCode}): {stripeMessage}");
        }

        return JsonDocument.Parse(responseBody);
    }

    public PaymentWebhookNotification VerifyWebhook(string payload, string signature)
    {
        if (string.IsNullOrWhiteSpace(_options.WebhookSecret))
            throw new InvalidOperationException("No está configurado Stripe__WebhookSecret.");

        var parts = signature.Split(',')
            .Select(part => part.Split('=', 2))
            .Where(part => part.Length == 2)
            .GroupBy(part => part[0])
            .ToDictionary(group => group.Key, group => group.Select(part => part[1]).ToArray());

        if (!parts.TryGetValue("t", out var timestamps) ||
            !long.TryParse(timestamps.FirstOrDefault(), NumberStyles.None, CultureInfo.InvariantCulture, out var timestamp) ||
            !parts.TryGetValue("v1", out var signatures))
            throw new UnauthorizedAccessException("Firma de webhook de Stripe inválida.");

        var now = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
        if (Math.Abs(now - timestamp) > 300)
            throw new UnauthorizedAccessException("El webhook de Stripe está fuera de la ventana de validez.");

        var signedPayload = Encoding.UTF8.GetBytes($"{timestamp}.{payload}");
        var secret = Encoding.UTF8.GetBytes(_options.WebhookSecret);
        var expected = HMACSHA256.HashData(secret, signedPayload);
        var valid = signatures.Any(candidate =>
        {
            try
            {
                var supplied = Convert.FromHexString(candidate);
                return supplied.Length == expected.Length && CryptographicOperations.FixedTimeEquals(supplied, expected);
            }
            catch (FormatException) { return false; }
        });
        if (!valid) throw new UnauthorizedAccessException("Firma de webhook de Stripe inválida.");

        using var json = JsonDocument.Parse(payload);
        var root = json.RootElement;
        var paymentIntent = root.GetProperty("data").GetProperty("object");
        return new PaymentWebhookNotification(
            root.GetProperty("id").GetString() ?? string.Empty,
            root.GetProperty("type").GetString() ?? string.Empty,
            paymentIntent.GetProperty("id").GetString() ?? string.Empty,
            paymentIntent.TryGetProperty("metadata", out var metadata) && metadata.TryGetProperty("checkout_attempt_id", out var attemptId)
                ? attemptId.GetString()
                : null);
    }
}
