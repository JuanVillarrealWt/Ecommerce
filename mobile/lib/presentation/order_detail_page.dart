import 'package:flutter/material.dart';

import '../application/order_use_cases.dart';
import '../domain/order.dart';

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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      order.name,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Chip(
                      backgroundColor: order.isConfirmed ? Colors.green.shade50 : Colors.amber.shade50,
                      label: Text(
                        order.isConfirmed ? 'Venta confirmada' : 'Cotización',
                        style: TextStyle(
                          color: order.isConfirmed ? Colors.green.shade800 : Colors.amber.shade900,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Cliente: ${order.partnerName} (ID ${order.partnerId})', style: const TextStyle(color: Colors.black54)),
                Text('Fecha: ${order.createdAt.toLocal().toString().split('.').first}', style: const TextStyle(color: Colors.black54)),
                const Divider(height: 32),
                Text('Artículos del pedido', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
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
                        subtitle: Text('${item.quantity} x \$${item.unitPrice.toStringAsFixed(2)}'),
                        trailing: Text(
                          '\$${item.subtotal.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      );
                    },
                  ),
                const Divider(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Odoo:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(
                      '\$${order.amountTotal.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF246B5A)),
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
}
