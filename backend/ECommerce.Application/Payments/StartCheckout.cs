using ECommerce.Application.Orders;
using ECommerce.Application.Customers;

namespace ECommerce.Application.Payments;

public sealed class StartCheckout(
    CreateOrder createDraftOrder,
    IPaymentGateway paymentGateway,
    IPaymentAttemptStore paymentAttemptStore,
    ICustomerService customerProfileStore,
    IReadOnlyList<DiscountCoupon> coupons,
    string currency)
{
    public async Task<CheckoutStarted> ExecuteAsync(
        int partnerId,
        IReadOnlyList<CreateOrderItemRequest> items,
        string? couponCode = null,
        OrderDeliveryAddress? deliveryAddress = null,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(currency))
            throw new InvalidOperationException("No está configurada la moneda de cobro.");

        var attemptId = Guid.NewGuid().ToString("N");
        IReadOnlyDictionary<int, decimal>? discounts = null;
        if (!string.IsNullOrWhiteSpace(couponCode))
        {
            var coupon = coupons.FirstOrDefault(item => string.Equals(item.Code, couponCode.Trim(), StringComparison.OrdinalIgnoreCase));
            if (coupon is null) throw new ArgumentException("El código de descuento no es válido.");
            if (coupon.Percentage <= 0 || coupon.Percentage > 100 || coupon.ProductIds.Count == 0)
                throw new InvalidOperationException("El código de descuento no está configurado correctamente.");
            discounts = items.Where(item => coupon.ProductIds.Contains(item.ProductId)).Select(item => item.ProductId).Distinct().ToDictionary(productId => productId, _ => coupon.Percentage);
            if (discounts.Count == 0) throw new ArgumentException("Este código no aplica a los productos de tu carrito.");
        }
        var order = await createDraftOrder.ExecuteAsync(
            partnerId,
            $"STRIPE-{attemptId[..16]}",
            items,
            discounts,
            deliveryAddress,
            cancellationToken);

        if (!string.Equals(order.CurrencyCode, currency, StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException(
                $"La moneda de la cotización de Odoo ({order.CurrencyCode}) no coincide con la moneda configurada para Stripe ({currency}).");

        if (order.AmountTotal <= 0)
            throw new InvalidOperationException("El total de Odoo debe ser mayor que cero para iniciar el pago.");

        var customerProfile = await customerProfileStore.GetByPartnerIdAsync(partnerId, cancellationToken)
            ?? throw new InvalidOperationException("No se encontró el perfil del cliente autenticado.");
        var stripeCustomerId = customerProfile.StripeCustomerId;
        if (string.IsNullOrWhiteSpace(stripeCustomerId))
        {
            var stripeCustomer = await paymentGateway.CreateCustomerAsync(
                customerProfile.Name, customerProfile.Email, partnerId, cancellationToken);
            stripeCustomerId = await customerProfileStore.SaveStripeCustomerIdIfMissingAsync(
                partnerId, stripeCustomer.CustomerId, cancellationToken);
        }

        var customerSession = await paymentGateway.CreateCustomerSessionAsync(
            stripeCustomerId, cancellationToken);

        var amountMinor = decimal.ToInt64(decimal.Round(order.AmountTotal * 100m, 0, MidpointRounding.AwayFromZero));
        var attempt = new PaymentAttempt(
            attemptId, partnerId, order.Id, order.Name, order.AmountTotal,
            currency.ToLowerInvariant(), "creating", null, DateTime.UtcNow);
        await paymentAttemptStore.AddAsync(attempt, cancellationToken);

        try
        {
            var intent = await paymentGateway.CreatePaymentIntentAsync(
                amountMinor, attempt.Currency, attemptId, order.Id, stripeCustomerId, cancellationToken);
            await paymentAttemptStore.UpdateAsync(attempt with
            {
                PaymentIntentId = intent.PaymentIntentId,
                Status = "pending"
            }, cancellationToken);

            return new CheckoutStarted(
                attemptId, intent.ClientSecret, stripeCustomerId, customerSession.ClientSecret,
                order.Name, order.AmountTotal, attempt.Currency);
        }
        catch
        {
            await paymentAttemptStore.UpdateAsync(attempt with { Status = "failed" }, cancellationToken);
            throw;
        }
    }
}
