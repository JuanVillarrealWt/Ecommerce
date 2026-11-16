import 'dart:convert';
import 'package:flutter/material.dart';

import '../application/auth_use_cases.dart';
import '../application/cart_use_cases.dart';
import '../application/get_categories.dart';
import '../application/get_products.dart';
import '../application/order_use_cases.dart';
import '../domain/cart.dart';
import '../domain/category.dart';
import '../domain/product.dart';
import 'product_detail_page.dart';

class CatalogPage extends StatefulWidget {
  const CatalogPage({
    required this.getProducts,
    required this.getCategories,
    required this.getCart,
    required this.addProductToCart,
    required this.setCartQuantity,
    required this.removeProductFromCart,
    required this.clearCart,
    required this.createOrder,
    required this.getCurrentCustomer,
    required this.onNavigateToAuth,
    required this.onNavigateToOrders,
    super.key,
  });

  final GetProducts getProducts;
  final GetCategories getCategories;
  final GetCart getCart;
  final AddProductToCart addProductToCart;
  final SetCartQuantity setCartQuantity;
  final RemoveProductFromCart removeProductFromCart;
  final ClearCart clearCart;
  final CreateOrderUseCase createOrder;
  final GetCurrentCustomerUseCase getCurrentCustomer;
  final VoidCallback onNavigateToAuth;
  final VoidCallback onNavigateToOrders;

  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  late Future<List<Product>> _productsFuture;
  late Future<List<Category>> _categoriesFuture;
  int? _selectedCategoryId;
  int _cartCount = 0;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadProducts();
    _refreshCartCount();
  }

  void _loadCategories() {
    _categoriesFuture = widget.getCategories();
  }

  void _loadProducts() {
    _productsFuture = widget.getProducts(categoryId: _selectedCategoryId);
  }

  Future<void> _refreshCartCount() async {
    final cart = await widget.getCart();
    if (mounted) {
      setState(() {
        _cartCount = cart.items.fold(0, (sum, item) => sum + item.quantity);
      });
    }
  }

  void _onCategorySelected(int? categoryId) {
    if (_selectedCategoryId == categoryId) return;
    setState(() {
      _selectedCategoryId = categoryId;
      _loadProducts();
    });
  }

  Future<void> _showCart() async {
    var cart = await widget.getCart();
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> update(Future<Cart> Function() action) async {
            cart = await action();
            setSheetState(() {});
            await _refreshCartCount();
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Tu Carrito', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                      if (!cart.isEmpty)
                        TextButton.icon(
                          onPressed: () => update(() => widget.clearCart()),
                          icon: const Icon(Icons.delete_sweep, size: 20),
                          label: const Text('Vaciar'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (cart.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.remove_shopping_cart_outlined, size: 48, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('Aún no agregas productos al carrito.'),
                          ],
                        ),
                      ),
                    ),
                  if (!cart.isEmpty) ...[
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          for (final item in cart.items)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text('\$${item.product.price.toStringAsFixed(2)} c/u · Subtotal: \$${item.subtotal.toStringAsFixed(2)}'),
                              leading: IconButton(
                                tooltip: 'Disminuir',
                                onPressed: item.quantity > 1
                                    ? () => update(() => widget.setCartQuantity(item.product.id, item.quantity - 1))
                                    : null,
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  IconButton(
                                    tooltip: 'Aumentar',
                                    onPressed: () => update(() => widget.setCartQuantity(item.product.id, item.quantity + 1)),
                                    icon: const Icon(Icons.add_circle_outline),
                                  ),
                                  IconButton(
                                    tooltip: 'Quitar',
                                    onPressed: () => update(() => widget.removeProductFromCart(item.product.id)),
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subtotal orientativo:', style: TextStyle(fontSize: 16)),
                        Text(
                          '\$${cart.subtotal.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF246B5A)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text('El importe final e impuestos se confirman con Odoo.', style: TextStyle(fontSize: 12, color: Colors.black54)),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF246B5A)),
                        onPressed: () async {
                          final customer = widget.getCurrentCustomer();
                          if (customer == null) {
                            Navigator.pop(context); // cerrar sheet
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Debe iniciar sesión para confirmar el pedido.')),
                            );
                            widget.onNavigateToAuth();
                            return;
                          }

                          // Confirmar pedido
                          try {
                            Navigator.pop(context);
                            showDialog<void>(
                              context: context,
                              barrierDismissible: false,
                              builder: (_) => const Center(child: CircularProgressIndicator()),
                            );

                            final order = await widget.createOrder(cart.items);
                            await widget.clearCart();
                            await _refreshCartCount();

                            if (mounted) {
                              Navigator.pop(context); // quitar loading
                              showDialog<void>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Row(
                                    children: [
                                      Icon(Icons.check_circle, color: Colors.green),
                                      SizedBox(width: 8),
                                      Text('¡Pedido Confirmado!'),
                                    ],
                                  ),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Se registró exitosamente en Odoo con el número: ${order.name}'),
                                      const SizedBox(height: 8),
                                      Text('Total verificado: \$${order.amountTotal.toStringAsFixed(2)}'),
                                      Text('Estado: ${order.isConfirmed ? 'Orden de venta confirmada' : 'Cotización'}'),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('Seguir comprando'),
                                    ),
                                    FilledButton(
                                      onPressed: () {
                                        Navigator.pop(ctx);
                                        widget.onNavigateToOrders();
                                      },
                                      child: const Text('Ver mis pedidos'),
                                    ),
                                  ],
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              Navigator.pop(context); // quitar loading
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error al procesar el pedido: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.shopping_bag_checkout),
                        label: const Text('Confirmar Pedido', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catálogo de Productos', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: 'Carrito ($_cartCount)',
            onPressed: _showCart,
            icon: Badge(
              label: Text('$_cartCount'),
              isLabelVisible: _cartCount > 0,
              child: const Icon(Icons.shopping_cart_outlined),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Barra de categorías horizontal (RF-02)
          FutureBuilder<List<Category>>(
            future: _categoriesFuture,
            builder: (context, snapshot) {
              final categories = snapshot.data ?? [];
              return SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: [
                    FilterChip(
                      label: const Text('Todos'),
                      selected: _selectedCategoryId == null,
                      onSelected: (_) => _onCategorySelected(null),
                    ),
                    const SizedBox(width: 8),
                    for (final cat in categories) ...[
                      FilterChip(
                        label: Text(cat.name),
                        selected: _selectedCategoryId == cat.id,
                        onSelected: (_) => _onCategorySelected(cat.id),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              );
            },
          ),
          // Lista de productos
          Expanded(
            child: FutureBuilder<List<Product>>(
              future: _productsFuture,
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
                          const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
                          const SizedBox(height: 12),
                          const Text('No pudimos cargar el catálogo desde la API.', textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: () => setState(_loadProducts),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final products = snapshot.data ?? const [];
                if (products.isEmpty) {
                  return const Center(child: Text('No hay productos disponibles en esta categoría.'));
                }
                return RefreshIndicator(
                  onRefresh: () async => setState(_loadProducts),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: products.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final product = products[index];
                      return _ProductCard(
                        product: product,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProductDetailPage(
                                product: product,
                                onAddToCart: (p, q) async {
                                  await widget.addProductToCart(p, quantity: q);
                                  await _refreshCartCount();
                                },
                              ),
                            ),
                          );
                        },
                        onAdd: () async {
                          await widget.addProductToCart(product);
                          await _refreshCartCount();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Agregado: ${product.name}'),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          }
                        },
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

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.onTap,
    required this.onAdd,
  });

  final Product product;
  final VoidCallback onTap;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final image = product.imageUrl;
    Widget thumbnail = const Icon(Icons.shopping_bag_outlined, size: 36, color: Colors.grey);
    if (image != null && image.startsWith('data:image') && image.contains(',')) {
      try {
        thumbnail = Image.memory(
          base64Decode(image.split(',').last),
          fit: BoxFit.cover,
        );
      } catch (_) {}
    }

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(child: thumbnail),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.description ?? 'Sin descripción',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '\$${product.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF246B5A),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Agregar al carrito',
                onPressed: onAdd,
                icon: const Icon(Icons.add_shopping_cart),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
