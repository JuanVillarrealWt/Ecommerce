namespace ECommerce.Application.Payments;

public sealed class PrepareCheckoutConfirmation(
    IPaymentGateway paymentGateway,
    IPaymentAttemptStore paymentAttemptStore)
{
    public async Task<string> ExecuteAsync(
        int partnerId,
        string attemptId,
        CancellationToken cancellationToken = default)
    {
        var attempt = await paymentAttemptStore.GetAsync(attemptId, cancellationToken);
        if (attempt is null || attempt.PartnerId != partnerId)
            throw new KeyNotFoundException("No se encontró el pago para este perfil.");
        if (!string.Equals(attempt.Status, "pending", StringComparison.OrdinalIgnoreCase) ||
            string.IsNullOrWhiteSpace(attempt.PaymentIntentId))
            throw new InvalidOperationException("Este pago ya no está disponible para confirmarse.");

        return await paymentGateway.UpdatePaymentIntentSavePreferenceAsync(
            attempt.PaymentIntentId, cancellationToken);
    }
}
