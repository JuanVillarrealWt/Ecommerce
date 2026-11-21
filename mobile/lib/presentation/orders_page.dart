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
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _ordersFuture = widget.getCustomerOrders();
  }

  Future<void> _selectDateRange() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initialRange = DateTimeRange(
      start: _startDate ?? now.subtract(const Duration(days: 7)),
      end: _endDate ?? now,
    );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: today,
      initialDateRange: initialRange,
      helpText: 'Filtrar pedidos por fecha',
      cancelText: 'Cancelar',
      confirmText: 'Filtrar',
    );

    if (picked != null) {
      setState(() {
        _startDate = DateTime(
          picked.start.year,
          picked.start.month,
          picked.start.day,
          0,
          0,
          0,
        );
        _endDate = DateTime(
          picked.end.year,
          picked.end.month,
          picked.end.day,
          23,
          59,
          59,
        );
      });
    }
  }

  void _clearDateFilter() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final customer = widget.getCurrentCustomer();
    final colors = Theme.of(context).colorScheme;

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
                const Text(
                  'Inicia sesión para ver tu historial de pedidos.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.primary,
                  ),
                  onPressed: widget.onNavigateToAuth,
                  child: const Text('Iniciar sesión'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final hasDateFilter = _startDate != null || _endDate != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Pedidos'),
        actions: [
          IconButton(
            onPressed: _selectDateRange,
            icon: Icon(
              hasDateFilter ? Icons.filter_alt : Icons.filter_alt_outlined,
              color: hasDateFilter ? colors.primary : null,
            ),
            tooltip: 'Filtrar por fecha',
          ),
          IconButton(
            onPressed: () => setState(_load),
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de filtro por fechas (Desde - Hasta)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: colors.surfaceContainerLow,
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _selectDateRange,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: hasDateFilter
                              ? colors.primary
                              : colors.outlineVariant,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_month_outlined,
                            size: 18,
                            color: hasDateFilter
                                ? colors.primary
                                : colors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              hasDateFilter
                                  ? 'Desde: ${_formatDate(_startDate!)}   Hasta: ${_formatDate(_endDate!)}'
                                  : 'Filtrar por rango de fechas (Desde - Hasta)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: hasDateFilter
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: hasDateFilter
                                    ? colors.primary
                                    : colors.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (hasDateFilter) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _clearDateFilter,
                    icon: const Icon(Icons.close, size: 20),
                    tooltip: 'Limpiar filtro',
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<OrderModel>>(
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
                          const Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 12),
                          Text('Error al cargar pedidos: ${snapshot.error}'),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: () => setState(_load),
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final allOrders = snapshot.data ?? [];
                // Aplicar filtro de fecha desde - hasta
                final orders = allOrders.where((o) {
                  final orderDate = o.createdAt.toLocal();
                  if (_startDate != null && orderDate.isBefore(_startDate!))
                    return false;
                  if (_endDate != null && orderDate.isAfter(_endDate!))
                    return false;
                  return true;
                }).toList();

                if (orders.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () async => setState(_load),
                    child: ListView(
                      children: [
                        const SizedBox(height: 100),
                        Center(
                          child: Column(
                            children: [
                              Icon(
                                hasDateFilter
                                    ? Icons.event_busy_outlined
                                    : Icons.receipt_long_outlined,
                                size: 64,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                hasDateFilter
                                    ? 'No se encontraron pedidos en el rango de fechas seleccionado.'
                                    : 'Todavía no has realizado pedidos.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 16),
                              ),
                              if (hasDateFilter) ...[
                                const SizedBox(height: 12),
                                TextButton.icon(
                                  onPressed: _clearDateFilter,
                                  icon: const Icon(Icons.clear),
                                  label: const Text('Quitar filtro de fechas'),
                                ),
                              ],
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
                      final colors = Theme.of(context).colorScheme;
                      return Card(
                        elevation: 2,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: order.isConfirmed
                                ? colors.tertiaryContainer
                                : colors.secondaryContainer,
                            child: Icon(
                              order.isConfirmed
                                  ? Icons.check_circle_outline
                                  : Icons.pending_outlined,
                              color: order.isConfirmed
                                  ? colors.onTertiaryContainer
                                  : colors.onSecondaryContainer,
                            ),
                          ),
                          title: Text(
                            order.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Fecha: ${order.createdAt.toLocal().toString().split('.').first}',
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '\$${order.amountTotal.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                order.isConfirmed ? 'Confirmado' : 'Cotización',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: order.isConfirmed
                                      ? Colors.green.shade700
                                      : Colors.amber.shade800,
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
          ),
        ],
      ),
    );
  }
}
