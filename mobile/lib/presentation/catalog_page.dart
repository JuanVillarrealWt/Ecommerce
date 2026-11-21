import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/auth_use_cases.dart';
import '../application/cart_use_cases.dart';
import '../application/get_categories.dart';
import '../application/get_products.dart';
import '../application/order_use_cases.dart';
import '../domain/cart.dart';
import '../domain/category.dart';
import '../domain/product.dart';
import 'product_detail_page.dart';
import 'product_image.dart';

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
    required this.isDarkMode,
    required this.onToggleTheme,
    required this.cartSyncVersion,
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
  final bool isDarkMode;
  final VoidCallback onToggleTheme;
  final int cartSyncVersion;

  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  late Future<List<Product>> _productsFuture;
  late Future<List<Category>> _categoriesFuture;
  int? _selectedCategoryId;
  int _cartCount = 0;
  bool _isGridView = true;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadProducts();
    _refreshCartCount();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CatalogPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cartSyncVersion != widget.cartSyncVersion) {
      _refreshCartCount();
    }
  }

  void _loadCategories() {
    _categoriesFuture = widget.getCategories();
  }

  void _loadProducts() {
    _productsFuture = widget.getProducts(categoryId: _selectedCategoryId);
  }

  Widget _loginBanner(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(
            Icons.account_circle_outlined,
            color: colors.onSecondaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Inicia sesión para comprar y consultar tus pedidos.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colors.onSecondaryContainer,
              ),
            ),
          ),
          TextButton(
            onPressed: widget.onNavigateToAuth,
            child: const Text('Ingresar'),
          ),
        ],
      ),
    );
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

  Future<bool> _confirmAction(
    BuildContext ctx, {
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _showCart() async {
    var cart = await widget.getCart();
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (sheetContext) {
        var isSubmitting = false;
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            Future<void> update(Future<Cart> Function() action) async {
              cart = await action();
              setSheetState(() {});
              await _refreshCartCount();
            }

            return Dialog.fullscreen(
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            tooltip: 'Volver al catálogo',
                            onPressed: () => Navigator.pop(sheetContext),
                            icon: const Icon(Icons.arrow_back),
                          ),
                          Text(
                            'Tu Carrito',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          if (!cart.isEmpty)
                            TextButton.icon(
                              onPressed: () async {
                                final confirm = await _confirmAction(
                                  sheetContext,
                                  title: '¿Vaciar carrito?',
                                  message:
                                      '¿Estás seguro de que deseas eliminar todos los productos del carrito?',
                                );
                                if (confirm) {
                                  await update(() => widget.clearCart());
                                }
                              },
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
                                Icon(
                                  Icons.remove_shopping_cart_outlined,
                                  size: 48,
                                  color: Colors.grey,
                                ),
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
                                  leading: _cartProductThumbnail(
                                    item.product,
                                    size: 54,
                                  ),
                                  title: Text(
                                    item.product.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '\$${item.product.price.toStringAsFixed(2)} c/u · Subtotal: \$${item.subtotal.toStringAsFixed(2)}',
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: 'Disminuir',
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () async {
                                          if (item.quantity > 1) {
                                            await update(
                                              () => widget.setCartQuantity(
                                                item.product.id,
                                                item.quantity - 1,
                                              ),
                                            );
                                          } else {
                                            final confirm = await _confirmAction(
                                              sheetContext,
                                              title: '¿Eliminar producto?',
                                              message:
                                                  '¿Deseas eliminar "${item.product.name}" del carrito?',
                                            );
                                            if (confirm) {
                                              await update(
                                                () => widget
                                                    .removeProductFromCart(
                                                      item.product.id,
                                                    ),
                                              );
                                            }
                                          }
                                        },
                                        icon: const Icon(
                                          Icons.remove_circle_outline,
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () async {
                                          final controller =
                                              TextEditingController(
                                                text: '${item.quantity}',
                                              );
                                          controller.selection = TextSelection(
                                            baseOffset: 0,
                                            extentOffset: controller.text.length,
                                          );
                                          final newQty = await showDialog<int>(
                                            context: sheetContext,
                                            builder: (dialogCtx) => AlertDialog(
                                              title: Text(
                                                'Modificar cantidad: ${item.product.name}',
                                              ),
                                              content: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Stock disponible en Odoo: ${item.product.stock} unidades',
                                                  ),
                                                  const SizedBox(height: 12),
                                                  TextField(
                                                    controller: controller,
                                                    keyboardType:
                                                        TextInputType.number,
                                                    inputFormatters: [
                                                      TextInputFormatter.withFunction((oldValue, newValue) {
                                                        final text = newValue.text;
                                                        if (text.isEmpty) return newValue;
                                                        final parsed = int.tryParse(text);
                                                        if (!RegExp(r'^\d+$').hasMatch(text) || text.startsWith('0') || parsed == null || parsed > item.product.stock) return oldValue;
                                                        return newValue;
                                                      }),
                                                    ],
                                                    autofocus: true,
                                                    decoration:
                                                        const InputDecoration(
                                                          labelText:
                                                              'Cantidad deseada',
                                                          border:
                                                              OutlineInputBorder(),
                                                        ),
                                                  ),
                                                ],
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(dialogCtx),
                                                  child: const Text('Cancelar'),
                                                ),
                                                FilledButton(
                                                  onPressed: () {
                                                    final val = int.tryParse(controller.text);
                                                    if (val == null || val < 1 || val > item.product.stock) return;
                                                    Navigator.pop(
                                                      dialogCtx,
                                                      val,
                                                    );
                                                  },
                                                  child: const Text('Aceptar'),
                                                ),
                                              ],
                                            ),
                                          );

                                          if (newQty != null) {
                                            if (newQty <= 0) {
                                              final confirm = await _confirmAction(
                                                sheetContext,
                                                title: '¿Eliminar producto?',
                                                message:
                                                    '¿Deseas eliminar "${item.product.name}" del carrito?',
                                              );
                                              if (confirm) {
                                                await update(
                                                  () => widget
                                                      .removeProductFromCart(
                                                        item.product.id,
                                                      ),
                                                );
                                              }
                                            } else if (newQty >
                                                item.product.stock) {
                                              if (mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Stock insuficiente: solo disponemos de ${item.product.stock} unidades de ${item.product.name}.',
                                                    ),
                                                    backgroundColor: Colors.red,
                                                  ),
                                                );
                                              }
                                              await update(
                                                () => widget.setCartQuantity(
                                                  item.product.id,
                                                  item.product.stock,
                                                ),
                                              );
                                            } else {
                                              await update(
                                                () => widget.setCartQuantity(
                                                  item.product.id,
                                                  newQty,
                                                ),
                                              );
                                            }
                                          }
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: Colors.grey.shade400,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            '${item.quantity}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Aumentar',
                                        onPressed: item.quantity < item.product.stock ? () async {
                                            await update(
                                              () => widget.setCartQuantity(
                                                item.product.id,
                                                item.quantity + 1,
                                              ),
                                            );
                                          } : null,
                                        icon: const Icon(
                                          Icons.add_circle_outline,
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Quitar',
                                        onPressed: () async {
                                          final confirm = await _confirmAction(
                                            sheetContext,
                                            title: '¿Eliminar producto?',
                                            message:
                                                '¿Deseas eliminar "${item.product.name}" del carrito?',
                                          );
                                          if (confirm) {
                                            await update(
                                              () =>
                                                  widget.removeProductFromCart(
                                                    item.product.id,
                                                  ),
                                            );
                                          }
                                        },
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          color: Colors.red,
                                        ),
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
                            const Text(
                              'Subtotal orientativo:',
                              style: TextStyle(fontSize: 16),
                            ),
                            Text(
                              '\$${cart.subtotal.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(
                                  sheetContext,
                                ).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'El importe final e impuestos se confirman con Odoo.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              sheetContext,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Theme.of(
                                sheetContext,
                              ).colorScheme.primary,
                            ),
                            onPressed: isSubmitting
                                ? null
                                : () async {
                                    final customer = widget
                                        .getCurrentCustomer();
                                    if (customer == null) {
                                      Navigator.pop(
                                        sheetContext,
                                      ); // cerrar sheet
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Debe iniciar sesión para confirmar el pedido.',
                                          ),
                                        ),
                                      );
                                      widget.onNavigateToAuth();
                                      return;
                                    }

                                    setSheetState(() => isSubmitting = true);
                                    try {
                                      final order = await widget.createOrder(
                                        cart.items,
                                      );
                                      await widget.clearCart();
                                      await _refreshCartCount();

                                      if (mounted) {
                                        Navigator.pop(
                                          sheetContext,
                                        ); // quitar sheet
                                        showDialog<void>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Row(
                                              children: [
                                                Icon(
                                                  Icons.check_circle,
                                                  color: Colors.green,
                                                ),
                                                SizedBox(width: 8),
                                                Text('¡Pedido Confirmado!'),
                                              ],
                                            ),
                                            content: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Se registró exitosamente en Odoo con el número: ${order.name}',
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  'Total verificado: \$${order.amountTotal.toStringAsFixed(2)}',
                                                ),
                                                Text(
                                                  'Estado: ${order.isConfirmed ? 'Orden de venta confirmada' : 'Cotización'}',
                                                ),
                                              ],
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx),
                                                child: const Text(
                                                  'Seguir comprando',
                                                ),
                                              ),
                                              FilledButton(
                                                onPressed: () {
                                                  Navigator.pop(ctx);
                                                  widget.onNavigateToOrders();
                                                },
                                                child: const Text(
                                                  'Ver mis pedidos',
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      setSheetState(() => isSubmitting = false);
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Error al procesar el pedido: $e',
                                            ),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  },
                            icon: isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.shopping_cart_checkout),
                            label: Text(
                              isSubmitting
                                  ? 'Procesando en Odoo...'
                                  : 'Confirmar Pedido',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre o detalle...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
              )
            : const Text(
                'Catálogo de Productos',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
        actions: [
          IconButton(
            tooltip: _isGridView ? 'Ver como lista' : 'Ver como cuadrícula',
            icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),
          if (_isSearching)
            IconButton(
              tooltip: 'Cerrar búsqueda',
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchController.clear();
                  _searchQuery = '';
                });
              },
            )
          else
            IconButton(
              tooltip: 'Buscar producto',
              icon: const Icon(Icons.search),
              onPressed: () {
                setState(() {
                  _isSearching = true;
                });
              },
            ),
          IconButton(
            tooltip: 'Carrito ($_cartCount)',
            onPressed: _showCart,
            icon: Badge(
              label: Text('$_cartCount'),
              isLabelVisible: _cartCount > 0,
              child: const Icon(Icons.shopping_cart_outlined),
            ),
          ),
          IconButton(
            tooltip: widget.isDarkMode ? 'Modo claro' : 'Modo oscuro',
            icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.onToggleTheme,
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
              const storeCategoryNames = <String>{
                'Escalada',
                'Senderismo y trekking',
                'Camping',
                'Fitness y entrenamiento',
                'Ciclismo',
                'Ropa y accesorios deportivos',
              };
              final categories = (snapshot.data ?? [])
                  .where(
                    (category) =>
                        storeCategoryNames.contains(category.name.trim()),
                  )
                  .toList(growable: false);
              return SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
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
          if (widget.getCurrentCustomer() == null) _loginBanner(context),
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
                          const Icon(
                            Icons.wifi_off,
                            size: 48,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No pudimos cargar el catálogo. ${snapshot.error ?? ''}',
                            textAlign: TextAlign.center,
                          ),
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
                final allProducts = snapshot.data ?? const [];
                final query = _searchQuery.trim().toLowerCase();
                final products = query.isEmpty
                    ? allProducts
                    : allProducts.where((p) {
                        final nameMatch = p.name.toLowerCase().contains(query);
                        final descMatch =
                            p.description?.toLowerCase().contains(query) ??
                            false;
                        return nameMatch || descMatch;
                      }).toList();

                if (products.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            query.isNotEmpty
                                ? Icons.search_off
                                : Icons.inventory_2_outlined,
                            size: 48,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            query.isNotEmpty
                                ? 'No se encontraron productos para "$_searchQuery".'
                                : 'No hay productos disponibles en esta categoría.',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                          if (query.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _searchQuery = '';
                                });
                              },
                              icon: const Icon(Icons.clear),
                              label: const Text('Limpiar búsqueda'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => setState(_loadProducts),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      if (_isGridView) {
                        final columns = constraints.maxWidth >= 1000
                            ? 5
                            : constraints.maxWidth >= 760
                            ? 4
                            : constraints.maxWidth >= 520
                            ? 3
                            : 2;
                        return GridView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: products.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: .58,
                              ),
                          itemBuilder: (context, index) => _buildProductCard(
                            context,
                            products[index],
                            isGrid: true,
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: products.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) =>
                            _buildProductCard(context, products[index]),
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

  Widget _buildProductCard(
    BuildContext context,
    Product product, {
    bool isGrid = false,
  }) => _ProductCard(
    product: product,
    isGrid: isGrid,
    onTap: () async {
      final cart = await widget.getCart();
      final inCartQty = cart.items
          .where((item) => item.product.id == product.id)
          .fold<int>(0, (total, item) => total + item.quantity);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductDetailPage(
            product: product,
            maxAvailableQuantity: product.stock - inCartQty,
            onAddToCart: (p, q) async {
              await widget.addProductToCart(p, quantity: q);
              await _refreshCartCount();
            },
          ),
        ),
      );
    },
    onAdd: () async {
      if (!product.stockTracked) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Inventario no configurado en Odoo. No se puede agregar este producto.',
              ),
            ),
          );
        }
        return;
      }
      if (product.stock <= 0) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'El producto "${product.name}" está agotado en Odoo.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      final currentCart = await widget.getCart();
      final existingItem = currentCart.items
          .where((item) => item.product.id == product.id)
          .firstOrNull;
      final inCartQty = existingItem?.quantity ?? 0;

      if (inCartQty >= product.stock) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Stock máximo alcanzado: solo disponemos de ${product.stock} uds.',
              ),
              backgroundColor: Colors.orange.shade800,
            ),
          );
        }
        return;
      }

      await widget.addProductToCart(product);
      await _refreshCartCount();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Agregado: ${product.name} (${inCartQty + 1} de ${product.stock} uds)',
            ),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    },
  );
}

Widget _cartProductThumbnail(Product product, {required double size}) {
  final image = product.imageUrl;
  final fallback = Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      color: Color(0xFFE8F5E9),
      shape: BoxShape.circle,
    ),
    child: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF388E3C)),
  );

  if (image == null || image.isEmpty) return fallback;
  Widget picture;
  if (image.startsWith('data:image') && image.contains(',')) {
    try {
      picture = Image.memory(
        base64Decode(image.substring(image.indexOf(',') + 1)),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      );
    } on FormatException {
      return fallback;
    }
  } else {
    picture = Image.network(
      image,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => fallback,
    );
  }

  return ClipOval(
    child: SizedBox(width: size, height: size, child: picture),
  );
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.onTap,
    required this.onAdd,
    this.isGrid = false,
  });

  final Product product;
  final VoidCallback onTap;
  final VoidCallback onAdd;
  final bool isGrid;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasStock = product.stockTracked && product.stock > 0;
    final stockLabel = !product.stockTracked
        ? 'Inventario sin configurar'
        : hasStock
        ? 'Stock ${product.stock}'
        : 'Agotado';
    final image = product.imageUrl;

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: isGrid
            ? Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        height: 96,
                        width: double.infinity,
                        color: colors.surfaceContainerHighest,
                        child: ProductImage(
                          imageUrl: image,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          iconSize: 36,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      product.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.description ?? 'Sin descripción',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 11,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '\$${product.price.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: colors.primary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          stockLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: hasStock
                                ? colors.onTertiaryContainer
                                : colors.onErrorContainer,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      height: 34,
                      child: FilledButton.tonalIcon(
                        onPressed: hasStock ? onAdd : null,
                        icon: const Icon(Icons.add_shopping_cart, size: 16),
                        label: const Text(
                          'Agregar',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 76,
                        height: 76,
                        color: colors.surfaceContainerHighest,
                        child: ProductImage(
                          imageUrl: image,
                          width: 76,
                          height: 76,
                          fit: BoxFit.cover,
                          iconSize: 32,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            product.description ?? 'Sin descripción',
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                '\$${product.price.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: colors.primary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: hasStock
                                      ? colors.tertiaryContainer
                                      : colors.errorContainer,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: hasStock
                                        ? colors.tertiary
                                        : colors.error,
                                  ),
                                ),
                                child: Text(
                                  stockLabel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: hasStock
                                        ? colors.onTertiaryContainer
                                        : colors.onErrorContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Agregar al carrito',
                      onPressed: hasStock ? onAdd : null,
                      icon: const Icon(Icons.add_shopping_cart),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
