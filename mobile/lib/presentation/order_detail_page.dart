import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:printing/printing.dart';

import '../application/order_use_cases.dart';
import '../domain/order.dart';
import '../infrastructure/order_pdf_service.dart';

class OrderDetailPage extends StatelessWidget {
  const OrderDetailPage({
    required this.orderId,
    required this.getOrderDetail,
    super.key,
  });

  final int orderId;
  final GetOrderDetailUseCase getOrderDetail;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Detalle del Pedido #$orderId')),
      body: FutureBuilder<OrderModel?>(
        future: getOrderDetail(orderId),
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
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _downloadPdf(context, order),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('Descargar comprobante PDF'),
                  ),
                ),
                const SizedBox(height: 16),
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
                        subtitle: Text(
                          '${item.quantity} x \$${item.unitPrice.toStringAsFixed(2)}',
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Odoo:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '\$${order.amountTotal.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: colors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
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
