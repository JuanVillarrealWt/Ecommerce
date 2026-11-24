import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart' hide Card;

import '../domain/checkout_payment.dart';
import 'stripe_checkout_config.dart';

Future<bool> presentCheckoutPayment(
  BuildContext context,
  CheckoutPayment checkout, {
  required Future<String> Function(bool shouldSavePaymentMethod)
  prepareConfirmation,
}) async {
  if (stripePublishableKey.isEmpty) {
    throw StateError(
      'Falta configurar STRIPE_PUBLISHABLE_KEY al compilar la aplicación.',
    );
  }

  return await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => _NativeCheckoutPage(
            checkout: checkout,
            prepareConfirmation: prepareConfirmation,
          ),
        ),
      ) ??
      false;
}

class _NativeCheckoutPage extends StatefulWidget {
  const _NativeCheckoutPage({
    required this.checkout,
    required this.prepareConfirmation,
  });

  final CheckoutPayment checkout;
  final Future<String> Function(bool shouldSavePaymentMethod)
  prepareConfirmation;

  @override
  State<_NativeCheckoutPage> createState() => _NativeCheckoutPageState();
}

class _NativeCheckoutPageState extends State<_NativeCheckoutPage> {
  final _elementController = EmbeddedPaymentElementController();
  bool _hasTouchedPayment = false;
  bool _elementLoaded = false;
  bool _submitting = false;
  bool _allowPop = false;
  String? _error;

  IntentConfiguration get _intentConfiguration => IntentConfiguration(
    mode: IntentMode.paymentMode(
      currencyCode: widget.checkout.currency.toLowerCase(),
      amount: (widget.checkout.amountTotal * 100).round(),
      setupFutureUsage: IntentFutureUsage.OffSession,
    ),
    paymentMethodTypes: const ['card'],
    confirmHandler: (_, shouldSavePaymentMethod) async {
      try {
        final clientSecret = await widget.prepareConfirmation(
          shouldSavePaymentMethod,
        );
        await Stripe.instance.intentCreationCallback(
          IntentCreationCallbackParams(clientSecret: clientSecret),
        );
      } catch (error) {
        await Stripe.instance.intentCreationCallback(
          IntentCreationCallbackParams(
            error: StripeException(
              error: LocalizedErrorMessage(
                code: FailureCode.Failed,
                localizedMessage: error.toString(),
              ),
            ),
          ),
        );
      }
    },
  );

  SetupPaymentSheetParameters get _paymentElementConfiguration =>
      SetupPaymentSheetParameters(
        merchantDisplayName: 'Entre Cumbres',
        customerId: widget.checkout.customerId,
        customerSessionClientSecret:
            widget.checkout.customerSessionClientSecret,
        returnURL: 'entrecumbres://stripe-redirect',
        linkDisplayParams: const LinkDisplayParams(
          linkDisplay: LinkDisplay.never,
        ),
        appearance: PaymentSheetAppearance(
          colors: PaymentSheetAppearanceColors(
            primary: Theme.of(context).colorScheme.primary,
            background: Theme.of(context).scaffoldBackgroundColor,
            componentBackground: Theme.of(context).colorScheme.surfaceContainer,
            componentBorder: Theme.of(context).colorScheme.outlineVariant,
            primaryText: Theme.of(context).colorScheme.onSurface,
            secondaryText: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );

  @override
  void dispose() {
    _elementController.dispose();
    super.dispose();
  }

  void _markPaymentTouched() {
    if (_hasTouchedPayment) return;
    setState(() => _hasTouchedPayment = true);
  }

  Future<void> _requestClose() async {
    if (_submitting) return;

    if (_hasTouchedPayment) {
      final shouldDiscard = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('¿Salir del pago?'),
          content: const Text(
            'Si sales ahora, tendrás que volver a ingresar los datos de pago.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Seguir pagando'),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Salir'),
            ),
          ],
        ),
      );
      if (shouldDiscard != true || !mounted) return;
    }

    setState(() => _allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop(false);
  }

  Future<void> _pay() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final result = await _elementController.confirm();
      if (!mounted) return;

      switch (result?['status']) {
        case 'completed':
          Navigator.of(context).pop(true);
          return;
        case 'canceled':
          setState(() => _submitting = false);
          return;
        case 'failed':
          setState(() {
            _submitting = false;
            _error =
                (result?['error'] as String?) ??
                'Stripe no pudo completar el pago. Revisa los datos e inténtalo de nuevo.';
          });
          return;
        default:
          setState(() {
            _submitting = false;
            _error =
                'No se pudo confirmar el pago. Revisa los datos e inténtalo de nuevo.';
          });
      }
    } on StripeException catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error =
            error.error.localizedMessage ??
            'No se pudo procesar el pago. Revisa los datos e inténtalo de nuevo.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error =
            'No se pudo procesar el pago. Revisa tu conexión e inténtalo de nuevo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: _allowPop || (!_hasTouchedPayment && !_submitting),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestClose();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Información de pago'),
          leading: IconButton(
            tooltip: 'Volver',
            onPressed: _submitting ? null : _requestClose,
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                      children: [
                        _OrderSummary(checkout: widget.checkout),
                        const SizedBox(height: 24),
                        Text(
                          'Forma de pago',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Listener(
                          behavior: HitTestBehavior.translucent,
                          onPointerDown: (_) => _markPaymentTouched(),
                          child: Stack(
                            alignment: Alignment.topCenter,
                            children: [
                              EmbeddedPaymentElement(
                                controller: _elementController,
                                intentConfiguration: _intentConfiguration,
                                configuration: _paymentElementConfiguration,
                                onHeightChanged: (_) {
                                  if (mounted && !_elementLoaded) {
                                    setState(() => _elementLoaded = true);
                                  }
                                },
                                onPaymentOptionChanged: (_) {
                                  _markPaymentTouched();
                                  if (mounted && !_elementLoaded) {
                                    setState(() => _elementLoaded = true);
                                  }
                                },
                                onLoadingFailed: (error) {
                                  if (!mounted) return;
                                  setState(() {
                                    _elementLoaded = true;
                                    _error =
                                        'Stripe no pudo cargar el formulario: ${error.message}';
                                  });
                                },
                                androidPlatformViewRenderType:
                                    AndroidPlatformViewRenderType
                                        .expensiveAndroidView,
                              ),
                              if (!_elementLoaded && _error == null)
                                Positioned.fill(
                                  child: ColoredBox(
                                    color: theme.colorScheme.surface,
                                    child: Center(
                                      child: const CircularProgressIndicator(),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: theme.colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
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

class _OrderSummary extends StatelessWidget {
  const _OrderSummary({required this.checkout});

  final CheckoutPayment checkout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.receipt_long_outlined, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pedido ${checkout.orderName}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Total ${checkout.currency.toUpperCase()} ${checkout.amountTotal.toStringAsFixed(2)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
