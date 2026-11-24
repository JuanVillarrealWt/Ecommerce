using ECommerce.Application.Orders;
using ECommerce.Application.CustomerFeatures;

namespace ECommerce.Application.Payments;

public sealed class ProcessPaymentWebhook(
    IOrderService orderService,
    IPaymentAttemptStore paymentAttemptStore,
    ManageCustomerFeatures customerFeatures,
    IOrderSnapshotStore orderSnapshots)
{
    public async Task ExecuteAsync(
        PaymentWebhookNotification notification,
        CancellationToken cancellationToken = default)
    {
        var attempt = !string.IsNullOrWhiteSpace(notification.AttemptId)
            ? await paymentAttemptStore.GetAsync(notification.AttemptId, cancellationToken)
            : await paymentAttemptStore.FindByPaymentIntentAsync(notification.PaymentIntentId, cancellationToken);
        if (attempt is null) return;
        if (attempt.PaymentIntentId is not null && attempt.PaymentIntentId != notification.PaymentIntentId) return;
        if (attempt.PaymentIntentId is null)
        {
            attempt = attempt with { PaymentIntentId = notification.PaymentIntentId };
            await paymentAttemptStore.UpdateAsync(attempt, cancellationToken);
        }

        switch (notification.EventType)
        {
            case "payment_intent.processing":
                if (attempt.Status != "paid")
                    await paymentAttemptStore.UpdateAsync(attempt with { Status = "processing" }, cancellationToken);
                break;
            case "payment_intent.succeeded":
                if (attempt.Status == "paid") return;
                var confirmedOrder = await orderService.ConfirmOrderAsync(
                    attempt.OrderId,
                    cancellationToken);
                await orderSnapshots.CaptureIfMissingAsync(
                    confirmedOrder,
                    cancellationToken);
                await paymentAttemptStore.UpdateAsync(attempt with { Status = "paid" }, cancellationToken);
                await customerFeatures.UpdateAsync(attempt.PartnerId, data =>
                {
                    data.Notifications.Insert(0, new CustomerNotification(Guid.NewGuid(), "payment", "Pago confirmado", $"El pago de {attempt.OrderName} fue procesado correctamente.", attempt.OrderId, DateTime.UtcNow, false));
                    if (data.Notifications.Count > 100) data.Notifications.RemoveAt(data.Notifications.Count - 1);
                }, cancellationToken);
                break;
            case "payment_intent.payment_failed":
                if (attempt.Status != "paid")
                    await paymentAttemptStore.UpdateAsync(attempt with { Status = "failed" }, cancellationToken);
                break;
            case "payment_intent.canceled":
                if (attempt.Status != "paid")
                    await paymentAttemptStore.UpdateAsync(attempt with { Status = "canceled" }, cancellationToken);
                break;
        }
    }
}
