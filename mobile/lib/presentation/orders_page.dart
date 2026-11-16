import 'package:flutter/material.dart';

import '../application/auth_use_cases.dart';
import '../application/order_use_cases.dart';
import '../domain/order.dart';
import 'order_detail_page.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({
    required this.getCustomerOrders,
    required this.getOrderDetail,
    required this.getCurrentCustomer,
    required this.onNavigateToAuth,
    super.key,
  });

  final GetCustomerOrdersUseCase getCustomerOrders;
  final GetOrderDetailUseCase getOrderDetail;
  final GetCurrentCustomerUseCase getCurrentCustomer;
  final VoidCallback onNavigateToAuth;

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  late Future<List<OrderModel>> _ordersFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _ordersFuture = widget.getCustomerOrders();
  }

  @override
  Widget build(BuildContext context) {
    final customer = widget.getCurrentCustomer();

    if (customer == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mis Pedidos')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 60, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('Inicia sesión para ver tu historial de pedidos.', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF246B5A)),
                  onPressed: widget.onNavigateToAuth,
                  child: const Text('Iniciar sesión'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Pedidos'),
        actions: [
          IconButton(
            onPressed: () => setState(_load),
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: FutureBuilder<List<OrderModel>>(
        future: _ordersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text('Error al cargar pedidos: ${snapshot.error}'),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: () => setState(_load), child: const Text('Reintentar')),
                  ],
                ),
              ),
            );
          }

          final orders = snapshot.data ?? [];
          if (orders.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async => setState(_load),
              child: ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('Todavía no has realizado pedidos.'),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => setState(_load),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final order = orders[index];
                return Card(
                  elevation: 2,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: order.isConfirmed ? Colors.green.shade100 : Colors.amber.shade100,
                      child: Icon(
                        order.isConfirmed ? Icons.check_circle_outline : Icons.pending_outlined,
                        color: order.isConfirmed ? Colors.green.shade800 : Colors.amber.shade900,
                      ),
                    ),
                    title: Text(order.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Fecha: ${order.createdAt.toLocal().toString().split('.').first}'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '\$${order.amountTotal.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          order.isConfirmed ? 'Confirmado' : 'Cotización',
                          style: TextStyle(
                            fontSize: 12,
                            color: order.isConfirmed ? Colors.green.shade700 : Colors.amber.shade800,
                          ),
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OrderDetailPage(
                            orderId: order.id,
                            getOrderDetail: widget.getOrderDetail,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
