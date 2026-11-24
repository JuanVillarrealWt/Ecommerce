import 'package:flutter/material.dart';

import '../application/auth_use_cases.dart';
import '../application/order_use_cases.dart';
import '../application/customer_features_repository.dart';
import '../domain/order.dart';
import 'order_detail_page.dart';

enum _DateFilterAction { change, clear }

class OrdersPage extends StatefulWidget {
  const OrdersPage({
    required this.refreshVersion,
    required this.getCustomerOrders,
    required this.getOrderDetail,
    required this.markOrderReceived,
    required this.getCurrentCustomer,
    required this.onNavigateToAuth,
    required this.customerFeaturesRepository,
    super.key,
  });

  final int refreshVersion;
  final GetCustomerOrdersUseCase getCustomerOrders;
  final GetOrderDetailUseCase getOrderDetail;
  final MarkOrderReceivedUseCase markOrderReceived;
  final GetCurrentCustomerUseCase getCurrentCustomer;
  final VoidCallback onNavigateToAuth;
  final CustomerFeaturesRepository customerFeaturesRepository;

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

  @override
  void didUpdateWidget(covariant OrdersPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshVersion != oldWidget.refreshVersion) _load();
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
          if (hasDateFilter)
            PopupMenuButton<_DateFilterAction>(
              tooltip: 'Filtrar por fecha',
              icon: Icon(Icons.filter_alt, color: colors.primary),
              onSelected: (action) {
                if (action == _DateFilterAction.change) {
                  _selectDateRange();
                } else {
                  _clearDateFilter();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _DateFilterAction.change,
                  child: Text('Cambiar rango de fechas'),
                ),
                PopupMenuItem(
                  value: _DateFilterAction.clear,
                  child: Text('Quitar filtro'),
                ),
              ],
            )
          else
            IconButton(
              onPressed: _selectDateRange,
              icon: const Icon(Icons.filter_alt_outlined),
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
                                order.received
                                    ? 'Recibido'
                                    : (order.isConfirmed
                                          ? 'Confirmado'
                                          : 'Cotización'),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: order.isConfirmed
                                      ? Colors.green.shade700
                                      : Colors.amber.shade800,
                                ),
                              ),
                            ],
                          ),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => OrderDetailPage(
                                  orderId: order.id,
                                  getOrderDetail: widget.getOrderDetail,
                                  markOrderReceived: widget.markOrderReceived,
                                  customerFeaturesRepository:
                                      widget.customerFeaturesRepository,
                                ),
                              ),
                            );
                            if (mounted) setState(_load);
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
