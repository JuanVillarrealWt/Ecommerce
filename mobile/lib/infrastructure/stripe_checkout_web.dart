import 'package:flutter/material.dart';
import 'package:flutter_stripe_web/flutter_stripe_web.dart';

import '../domain/checkout_payment.dart';
import 'stripe_checkout_config.dart';

Future<bool> presentCheckoutPayment(
  BuildContext context,
  CheckoutPayment checkout, {
  Future<String> Function(bool shouldSavePaymentMethod)? prepareConfirmation,
}) async {
  if (stripePublishableKey.isEmpty) {
    throw StateError(
      'Falta configurar STRIPE_PUBLISHABLE_KEY al compilar la aplicación.',
    );
  }
  return await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => _WebCheckoutPage(checkout: checkout)),
      ) ??
      false;
}

class _WebCheckoutPage extends StatefulWidget {
  const _WebCheckoutPage({required this.checkout});

  final CheckoutPayment checkout;

  @override
  State<_WebCheckoutPage> createState() => _WebCheckoutPageState();
}

class _WebCheckoutPageState extends State<_WebCheckoutPage> {
  bool _submitting = false;
  String? _error;

  Future<void> _pay() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await WebStripe.instance.confirmPaymentElement(
        ConfirmPaymentElementOptions(
          confirmParams: ConfirmPaymentParams(return_url: Uri.base.toString()),
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error =
              'No se pudo completar el pago. Revisa los datos e inténtalo de nuevo.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: !_submitting,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pago seguro'),
          leading: IconButton(
            tooltip: 'Volver al carrito',
            onPressed: _submitting
                ? null
                : () => Navigator.of(context).pop(false),
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        Text('Pedido ${widget.checkout.orderName}'),
                        const SizedBox(height: 6),
                        Text(
                          '${widget.checkout.currency.toUpperCase()} ${widget.checkout.amountTotal.toStringAsFixed(2)}',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        PaymentElement(
                          clientSecret: widget.checkout.clientSecret,
                          customerSessionClientSecret:
                              widget.checkout.customerSessionClientSecret,
                          enablePostalCode: true,
                          appearance: const ElementAppearance(
                            theme: ElementTheme.flat,
                            variables: {
                              'colorPrimary': '#246B5A',
                              'colorBackground': '#FFFFFF',
                              'colorText': '#18352D',
                              'colorDanger': '#B42318',
                              'borderRadius': '14px',
                              'fontFamily': 'system-ui, sans-serif',
                            },
                          ),
                          onCardChanged: (_) {},
                        ),
                        if (stripePublishableKey.startsWith('pk_test_')) ...[
                          const SizedBox(height: 12),
                          Text(
                            'Tarjeta de prueba: 4242 4242 4242 4242. Usa una fecha futura y cualquier CVC de 3 dígitos.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _submitting ? null : _pay,
                        icon: _submitting
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.lock_outline),
                        label: Text(
                          _submitting
                              ? 'Procesando pago…'
                              : 'Pagar ${widget.checkout.currency.toUpperCase()} ${widget.checkout.amountTotal.toStringAsFixed(2)}',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
