import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:printing/printing.dart';

import '../application/order_use_cases.dart';
import '../domain/order.dart';
import '../infrastructure/order_pdf_service.dart';
import '../application/customer_features_repository.dart';

class OrderDetailPage extends StatefulWidget {
  const OrderDetailPage({
    required this.orderId,
    required this.getOrderDetail,
    required this.markOrderReceived,
    required this.customerFeaturesRepository,
    super.key,
  });

  final int orderId;
  final GetOrderDetailUseCase getOrderDetail;
  final MarkOrderReceivedUseCase markOrderReceived;
  final CustomerFeaturesRepository customerFeaturesRepository;

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  late Future<OrderModel?> _orderFuture;

  @override
  void initState() {
    super.initState();
    _orderFuture = widget.getOrderDetail(widget.orderId);
  }

  Future<void> _confirmReceipt(OrderModel order) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => PopScope(
            canPop: false,
            child: AlertDialog(
              title: const Text('¿Confirmas que recibiste tu pedido?'),
              content: const Text(
                'Esta confirmación se guardará en tu cuenta.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Todavía no'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Sí, lo recibí'),
                ),
              ],
            ),
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    try {
      await widget.markOrderReceived(order.id);
      if (!mounted) return;
      setState(() {
        _orderFuture = Future.value(
          OrderModel(
            id: order.id,
            name: order.name,
            partnerId: order.partnerId,
            partnerName: order.partnerName,
            state: order.state,
            amountTotal: order.amountTotal,
            amountUntaxed: order.amountUntaxed,
            amountTax: order.amountTax,
            received: true,
            createdAt: order.createdAt,
            items: order.items,
          ),
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recepción del pedido confirmada.')),
      );
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo confirmar la recepción. Intenta de nuevo.',
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Detalle del Pedido #${widget.orderId}')),
      body: FutureBuilder<OrderModel?>(
        future: _orderFuture,
        builder: (context, snapshot) {
          final colors = Theme.of(context).colorScheme;
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Error: ${snapshot.error}'),
              ),
            );
          }
          final order = snapshot.data;
          if (order == null) {
            return const Center(child: Text('Pedido no encontrado.'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (order.isConfirmed) ...[
                  SizedBox(
                    width: double.infinity,
                    child: order.received
                        ? const Chip(
                            avatar: Icon(Icons.check_circle_outline),
                            label: Text('Producto recibido'),
                          )
                        : FilledButton.tonalIcon(
                            onPressed: () => _confirmReceipt(order),
                            icon: const Icon(Icons.inventory_2_outlined),
                            label: const Text(
                              'Confirmar que recibí el producto',
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (order.isConfirmed) ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _downloadPdf(context, order),
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('Descargar comprobante PDF'),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      order.name,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Chip(
                      backgroundColor: order.isConfirmed
                          ? colors.tertiaryContainer
                          : colors.secondaryContainer,
                      label: Text(
                        order.isConfirmed ? 'Venta confirmada' : 'Cotización',
                        style: TextStyle(
                          color: order.isConfirmed
                              ? colors.onTertiaryContainer
                              : colors.onSecondaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Cliente: ${order.partnerName} (ID ${order.partnerId})',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
                Text(
                  'Fecha: ${order.createdAt.toLocal().toString().split('.').first}',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
                const Divider(height: 32),
                Text(
                  'Artículos del pedido',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                if (order.items.isEmpty)
                  const Text('No se registraron líneas detalladas.')
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: order.items.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (context, index) {
                      final item = order.items[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(item.productName),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${item.quantity} x \$${item.unitPrice.toStringAsFixed(2)}',
                            ),
                            if (order.isConfirmed)
                              TextButton.icon(
                                onPressed: () =>
                                    _review(context, item.productId, order.id),
                                icon: const Icon(Icons.star_outline, size: 18),
                                label: const Text('Calificar o editar reseña'),
                              ),
                          ],
                        ),
                        trailing: Text(
                          '\$${item.subtotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      );
                    },
                  ),
                const Divider(height: 32),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _amountRow(
                          'Subtotal sin impuestos',
                          order.amountUntaxed,
                        ),
                        const SizedBox(height: 8),
                        _amountRow('IVA / impuestos', order.amountTax),
                        const Divider(height: 24),
                        _amountRow(
                          'Total Odoo',
                          order.amountTotal,
                          bold: true,
                          color: colors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _amountRow(
    String label,
    double amount, {
    bool bold = false,
    Color? color,
  }) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: bold ? 18 : 14,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      Text(
        '\$${amount.toStringAsFixed(2)}',
        style: TextStyle(
          fontSize: bold ? 21 : 15,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          color: color,
        ),
      ),
    ],
  );

  Future<void> _review(BuildContext context, int productId, int orderId) async {
    Map<String, dynamic>? existingReview;
    try {
      final data = await widget.customerFeaturesRepository.load();
      final reviews = (data['reviews'] as List? ?? const [])
          .whereType<Map>()
          .map((review) => Map<String, dynamic>.from(review));
      for (final review in reviews) {
        if (review['productId'] == productId) {
          existingReview = review;
          break;
        }
      }
    } catch (_) {
      // The user can still submit a new rating if the existing review cannot load.
    }
    if (!context.mounted) return;

    var rating = existingReview?['rating'] as int? ?? 5;
    final comment = TextEditingController(
      text: existingReview?['comment'] as String? ?? '',
    );
    var isDirty = false;
    Future<void> requestClose(
      BuildContext dialogContext, {
      required bool submitted,
    }) async {
      var shouldClose = !isDirty;
      if (isDirty) {
        shouldClose =
            await showDialog<bool>(
              context: dialogContext,
              barrierDismissible: false,
              builder: (confirmContext) => AlertDialog(
                title: const Text('¿Descartar cambios?'),
                content: const Text(
                  'Tienes cambios en tu calificación. ¿Quieres salir sin guardarlos?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(confirmContext, false),
                    child: const Text('Seguir editando'),
                  ),
                  FilledButton.tonal(
                    onPressed: () => Navigator.pop(confirmContext, true),
                    child: const Text('Descartar'),
                  ),
                ],
              ),
            ) ==
            true;
      }
      if (shouldClose && dialogContext.mounted) {
        Navigator.of(dialogContext).pop(submitted);
      }
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) requestClose(dialogContext, submitted: false);
        },
        child: StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: Text(
              existingReview == null
                  ? 'Califica este producto'
                  : 'Edita tu calificación',
            ),
            scrollable: true,
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var star = 1; star <= 5; star++)
                        IconButton(
                          constraints: const BoxConstraints.tightFor(
                            width: 36,
                            height: 36,
                          ),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          onPressed: () => setDialogState(() {
                            rating = star;
                            isDirty = true;
                          }),
                          icon: Icon(
                            star <= rating ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                          ),
                        ),
                    ],
                  ),
                  const Text(
                    'Puedes enviar solo las estrellas; el comentario es opcional.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: comment,
                    maxLength: 1000,
                    maxLines: 3,
                    onChanged: (_) => setDialogState(() => isDirty = true),
                    decoration: const InputDecoration(
                      labelText: 'Comentario (opcional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => requestClose(dialogContext, submitted: false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Enviar'),
              ),
            ],
          ),
        ),
      ),
    );
    if (result == true) {
      try {
        await widget.customerFeaturesRepository.submitReview(
          productId: productId,
          orderId: orderId,
          rating: rating,
          comment: comment.text.trim(),
        );
        if (context.mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                existingReview == null
                    ? 'Gracias por compartir tu opinión.'
                    : 'Tu calificación se actualizó correctamente.',
              ),
            ),
          );
      } catch (error) {
        if (context.mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => comment.dispose());
  }

  Future<void> _downloadPdf(BuildContext context, OrderModel order) async {
    try {
      final bytes = await OrderPdfService.build(order);
      final safeName = order.name.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      final fileName = 'Comprobante_$safeName.pdf';
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
        final location = await getSaveLocation(
          suggestedName: fileName,
          acceptedTypeGroups: const [
            XTypeGroup(label: 'Documento PDF', extensions: ['pdf']),
          ],
        );
        if (location == null) return;
        await XFile.fromData(
          bytes,
          mimeType: 'application/pdf',
          name: fileName,
        ).saveTo(location.path);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PDF guardado correctamente.')),
          );
        }
        return;
      }
      await Printing.layoutPdf(name: fileName, onLayout: (_) async => bytes);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo generar el PDF: $error')),
      );
    }
  }
}
