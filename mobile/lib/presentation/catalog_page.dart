import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/auth_use_cases.dart';
import '../application/cart_use_cases.dart';
import '../application/checkout_use_cases.dart';
import '../application/get_categories.dart';
import '../application/get_products.dart';
import '../application/customer_features_repository.dart';
import '../domain/checkout_payment.dart';
import '../domain/cart.dart';
import '../domain/cart_item.dart';
import '../domain/category.dart';
import '../domain/product.dart';
import 'product_detail_page.dart';
import 'product_image.dart';
import 'address_form_page.dart';
import '../infrastructure/stripe_checkout_platform.dart' as stripe_checkout;

class CatalogPage extends StatefulWidget {
  const CatalogPage({
    required this.getProducts,
    required this.getCategories,
    required this.getCart,
    required this.addProductToCart,
    required this.setCartQuantity,
    required this.removeProductFromCart,
    required this.clearCart,
    required this.startCheckout,
    required this.getCheckoutStatus,
    required this.getCurrentCustomer,
    required this.onNavigateToAuth,
    required this.onNavigateToOrders,
    required this.isDarkMode,
    required this.onToggleTheme,
    required this.cartSyncVersion,
    this.customerFeaturesRepository,
    super.key,
  });

  final GetProducts getProducts;
  final GetCategories getCategories;
  final GetCart getCart;
  final AddProductToCart addProductToCart;
  final SetCartQuantity setCartQuantity;
  final RemoveProductFromCart removeProductFromCart;
  final ClearCart clearCart;
  final StartCheckoutUseCase startCheckout;
  final GetCheckoutStatusUseCase getCheckoutStatus;
  final GetCurrentCustomerUseCase getCurrentCustomer;
  final VoidCallback onNavigateToAuth;
  final VoidCallback onNavigateToOrders;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;
  final int cartSyncVersion;
  final CustomerFeaturesRepository? customerFeaturesRepository;

  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  late Future<List<Product>> _productsFuture;
  late Future<List<Category>> _categoriesFuture;
  int? _selectedCategoryId;
  int _cartCount = 0;
  final Map<int, int> _cartQuantities = {};
  bool _isGridView = true;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'recommended';
  final Set<int> _favoriteProductIds = {};
  final Set<int> _purchasedProductIds = {};

  Future<void> _refreshCatalogAfterPurchase(
    List<CartItem> purchasedItems,
  ) async {
    final quantities = {
      for (final item in purchasedItems) item.product.id: item.quantity,
    };
    setState(() {
      _productsFuture = _productsFuture.then(
        (products) => products
            .map((product) {
              final quantity = quantities[product.id] ?? 0;
              if (!product.stockTracked || quantity == 0) return product;
              return Product(
                id: product.id,
                name: product.name,
                price: product.price,
                description: product.description,
                imageUrl: product.imageUrl,
                categoryIds: product.categoryIds,
                stock: (product.stock - quantity)
                    .clamp(0, product.stock)
                    .toInt(),
                stockTracked: product.stockTracked,
              );
            })
            .toList(growable: false),
      );
    });
    for (var attempt = 0; attempt < 5; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      try {
        final fresh = await widget.getProducts(categoryId: _selectedCategoryId);
        final inventoryUpdated = purchasedItems
            .where((item) => item.product.stockTracked)
            .every((item) {
              final product = fresh
                  .where((candidate) => candidate.id == item.product.id)
                  .firstOrNull;
              return product == null ||
                  product.stock <=
                      (item.product.stock - item.quantity).clamp(
                        0,
                        item.product.stock,
                      );
            });
        if (inventoryUpdated) {
          if (mounted) setState(() => _productsFuture = Future.value(fresh));
          return;
        }
      } catch (_) {
        // Keep the immediate local stock estimate if the API is still syncing.
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadProducts();
    _refreshCartCount();
    _loadFavorites();
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
      _loadFavorites();
    }
  }

  Future<void> _loadFavorites() async {
    if (widget.getCurrentCustomer() == null ||
        widget.customerFeaturesRepository == null) {
      if (mounted)
        setState(() {
          _favoriteProductIds.clear();
          _purchasedProductIds.clear();
        });
      return;
    }
    try {
      final data = await widget.customerFeaturesRepository!.load();
      final ids = (data['favoriteProductIds'] as List? ?? [])
          .whereType<int>()
          .toSet();
      final purchasedIds = (data['purchasedProductIds'] as List? ?? [])
          .whereType<int>()
          .toSet();
      if (mounted)
        setState(() {
          _favoriteProductIds
            ..clear()
            ..addAll(ids);
          _purchasedProductIds
            ..clear()
            ..addAll(purchasedIds);
        });
    } catch (_) {}
  }

  Future<bool> _toggleFavorite(Product product) async {
    if (widget.getCurrentCustomer() == null ||
        widget.customerFeaturesRepository == null) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Inicia sesión para guardar favoritos.'),
          ),
        );
      widget.onNavigateToAuth();
      return false;
    }
    final wasFavorite = _favoriteProductIds.contains(product.id);
    setState(() {
      if (wasFavorite) {
        _favoriteProductIds.remove(product.id);
      } else {
        _favoriteProductIds.add(product.id);
      }
    });
    try {
      if (wasFavorite) {
        await widget.customerFeaturesRepository!.removeFavorite(product.id);
      } else {
        await widget.customerFeaturesRepository!.addFavorite(product.id);
      }
      return true;
    } catch (error) {
      if (mounted) {
        setState(() {
          if (wasFavorite) {
            _favoriteProductIds.add(product.id);
          } else {
            _favoriteProductIds.remove(product.id);
          }
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
      return false;
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
      final quantities = <int, int>{};
      for (final item in cart.items) {
        quantities.update(
          item.product.id,
          (quantity) => quantity + item.quantity,
          ifAbsent: () => item.quantity,
        );
      }
      setState(() {
        _cartCount = cart.items.fold(0, (sum, item) => sum + item.quantity);
        _cartQuantities
          ..clear()
          ..addAll(quantities);
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

    var savedAddresses = <Map<String, dynamic>>[];
    final customer = widget.getCurrentCustomer();
    if (customer != null && widget.customerFeaturesRepository != null) {
      try {
        final data = await widget.customerFeaturesRepository!.load();
        savedAddresses = (data['addresses'] as List? ?? const [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      } catch (_) {
        // Address selection is optional when the account data cannot load.
      }
    }
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (sheetContext) {
        var isSubmitting = false;
        var addingAddress = false;
        var couponCode = '';
        String? couponError;
        final defaultAddressIndex = savedAddresses.indexWhere(
          (address) => address['isDefault'] == true,
        );
        var selectedAddressId = savedAddresses.isEmpty
            ? null
            : savedAddresses[defaultAddressIndex < 0
                      ? 0
                      : defaultAddressIndex]['id']
                  ?.toString();
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
                                            extentOffset:
                                                controller.text.length,
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
                                                      TextInputFormatter.withFunction(
                                                        (oldValue, newValue) {
                                                          final text =
                                                              newValue.text;
                                                          if (text.isEmpty)
                                                            return newValue;
                                                          final parsed =
                                                              int.tryParse(
                                                                text,
                                                              );
                                                          if (!RegExp(
                                                                r'^\d+$',
                                                              ).hasMatch(
                                                                text,
                                                              ) ||
                                                              text.startsWith(
                                                                '0',
                                                              ) ||
                                                              parsed == null ||
                                                              parsed >
                                                                  item
                                                                      .product
                                                                      .stock)
                                                            return oldValue;
                                                          return newValue;
                                                        },
                                                      ),
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
                                                    final val = int.tryParse(
                                                      controller.text,
                                                    );
                                                    if (val == null ||
                                                        val < 1 ||
                                                        val >
                                                            item.product.stock)
                                                      return;
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
                                        onPressed:
                                            item.quantity < item.product.stock
                                            ? () async {
                                                await update(
                                                  () => widget.setCartQuantity(
                                                    item.product.id,
                                                    item.quantity + 1,
                                                  ),
                                                );
                                              }
                                            : null,
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
                        const SizedBox(height: 10),
                        TextField(
                          onChanged: (value) => setSheetState(() {
                            couponCode = value;
                            couponError = null;
                          }),
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Código de descuento (opcional)',
                            hintText: 'Ejemplo: CUMBRES10',
                            prefixIcon: Icon(Icons.local_offer_outlined),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        if (couponError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6, left: 12),
                            child: Text(
                              couponError!,
                              style: TextStyle(
                                color: Theme.of(sheetContext).colorScheme.error,
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        if (savedAddresses.isNotEmpty) ...[
                          DropdownButtonFormField<String>(
                            initialValue: selectedAddressId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Dirección de entrega',
                              prefixIcon: Icon(Icons.location_on_outlined),
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              for (final address in savedAddresses)
                                DropdownMenuItem(
                                  value: address['id'].toString(),
                                  child: Text(
                                    '${address['label']} · ${address['street']}, ${address['city']}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (value) =>
                                setSheetState(() => selectedAddressId = value),
                          ),
                        ] else if (customer != null) ...[
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: addingAddress,
                            title: const Text(
                              'Registrar una dirección de entrega',
                            ),
                            subtitle: const Text(
                              'Necesitas una dirección guardada para pagar.',
                            ),
                            onChanged: (value) => setSheetState(
                              () => addingAddress = value ?? false,
                            ),
                          ),
                          if (addingAddress)
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed:
                                    widget.customerFeaturesRepository == null
                                    ? null
                                    : () async {
                                        final address =
                                            await Navigator.of(
                                              sheetContext,
                                            ).push<Map<String, dynamic>>(
                                              MaterialPageRoute(
                                                builder: (_) => AddressFormPage(
                                                  repository: widget
                                                      .customerFeaturesRepository!,
                                                  initialProvince:
                                                      customer.province,
                                                  initialPhone: customer.phone,
                                                  isPrimary: true,
                                                ),
                                              ),
                                            );
                                        if (address == null ||
                                            !sheetContext.mounted) {
                                          return;
                                        }
                                        setSheetState(() {
                                          savedAddresses.add(address);
                                          selectedAddressId = address['id']
                                              ?.toString();
                                          addingAddress = false;
                                        });
                                      },
                                icon: const Icon(
                                  Icons.add_location_alt_outlined,
                                ),
                                label: const Text('Agregar dirección'),
                              ),
                            ),
                          if (widget.customerFeaturesRepository == null)
                            const Text(
                              'No se pudo abrir el registro de direcciones. Intenta de nuevo.',
                            ),
                        ],
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
                            onPressed:
                                isSubmitting ||
                                    (widget.getCurrentCustomer() != null &&
                                        (savedAddresses.isEmpty ||
                                            selectedAddressId == null))
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

                                    if (savedAddresses.isEmpty ||
                                        selectedAddressId == null) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Registra y selecciona una dirección antes de pagar.',
                                          ),
                                        ),
                                      );
                                      return;
                                    }

                                    setSheetState(() => isSubmitting = true);
                                    try {
                                      final checkout = await widget
                                          .startCheckout(
                                            cart.items,
                                            couponCode: couponCode,
                                            savedAddressId: selectedAddressId,
                                          );
                                      if (!mounted || !sheetContext.mounted) {
                                        return;
                                      }
                                      final paymentSubmitted =
                                          await stripe_checkout
                                              .presentCheckoutPayment(
                                                context,
                                                checkout,
                                                prepareConfirmation:
                                                    (
                                                      shouldSavePaymentMethod,
                                                    ) => shouldSavePaymentMethod
                                                    ? widget.startCheckout
                                                          .prepareConfirmation(
                                                            checkout.attemptId,
                                                          )
                                                    : Future<String>.value(
                                                        checkout.clientSecret,
                                                      ),
                                              );
                                      if (!context.mounted ||
                                          !sheetContext.mounted) {
                                        return;
                                      }
                                      if (!paymentSubmitted) {
                                        setSheetState(
                                          () => isSubmitting = false,
                                        );
                                        return;
                                      }

                                      CheckoutPaymentStatus? paymentStatus;
                                      for (var i = 0; i < 25; i++) {
                                        try {
                                          paymentStatus = await widget
                                              .getCheckoutStatus(
                                                checkout.attemptId,
                                              );
                                          if (paymentStatus.status == 'paid' ||
                                              paymentStatus.status ==
                                                  'failed' ||
                                              paymentStatus.status ==
                                                  'canceled') {
                                            break;
                                          }
                                        } catch (_) {
                                          // A slow API connection leaves the payment pending for server verification.
                                        }
                                        await Future<void>.delayed(
                                          const Duration(seconds: 1),
                                        );
                                      }

                                      if (paymentStatus?.status == 'failed' ||
                                          paymentStatus?.status == 'canceled') {
                                        throw Exception(
                                          'El pago no se completó. No se confirmó el pedido.',
                                        );
                                      }

                                      await widget.clearCart();
                                      await _refreshCartCount();
                                      if (paymentStatus?.status == 'paid' &&
                                          mounted) {
                                        unawaited(
                                          _refreshCatalogAfterPurchase(
                                            cart.items,
                                          ),
                                        );
                                      }
                                      if (mounted &&
                                          context.mounted &&
                                          sheetContext.mounted) {
                                        Navigator.pop(sheetContext);
                                        final paymentConfirmed =
                                            paymentStatus?.status == 'paid';
                                        showDialog<void>(
                                          context: context,
                                          barrierDismissible: false,
                                          builder: (ctx) => AlertDialog(
                                            title: const Row(
                                              children: [
                                                Icon(
                                                  Icons.check_circle,
                                                  color: Colors.green,
                                                ),
                                                SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    '¡Pago recibido!',
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            content: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  paymentConfirmed
                                                      ? 'Tu pedido ${checkout.orderName} fue confirmado en Odoo.'
                                                      : 'Recibimos la confirmación del pago. Estamos verificando el pedido ${checkout.orderName}; aparecerá en Mis Pedidos en breve.',
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  'Total: ${checkout.currency.toUpperCase()} ${checkout.amountTotal.toStringAsFixed(2)}',
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
                                      if (!mounted || !sheetContext.mounted) {
                                        return;
                                      }
                                      setSheetState(() => isSubmitting = false);
                                      if (mounted) {
                                        final message = e
                                            .toString()
                                            .replaceFirst('HttpException: ', '')
                                            .replaceFirst('Exception: ', '');
                                        final invalidCoupon =
                                            couponCode.trim().isNotEmpty &&
                                            (message.toLowerCase().contains(
                                                  'código de descuento no es válido',
                                                ) ||
                                                message.toLowerCase().contains(
                                                  'no aplica a los productos',
                                                ));
                                        if (invalidCoupon) {
                                          setSheetState(
                                            () => couponError =
                                                'Código no válido o no aplicable a los productos del carrito.',
                                          );
                                          return;
                                        }
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
                                  ? 'Preparando pago seguro...'
                                  : 'Pagar con Stripe',
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
          if (!_isSearching)
            PopupMenuButton<String>(
              tooltip: 'Ordenar productos',
              icon: const Icon(Icons.sort),
              onSelected: (value) => setState(() => _sortBy = value),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'recommended',
                  child: Text('Recomendados'),
                ),
                PopupMenuItem(
                  value: 'price_asc',
                  child: Text('Precio: menor a mayor'),
                ),
                PopupMenuItem(
                  value: 'price_desc',
                  child: Text('Precio: mayor a menor'),
                ),
                PopupMenuItem(value: 'name', child: Text('Nombre: A a Z')),
              ],
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
                final products =
                    (query.isEmpty
                            ? allProducts
                            : allProducts.where((p) {
                                final nameMatch = p.name.toLowerCase().contains(
                                  query,
                                );
                                final descMatch =
                                    p.description?.toLowerCase().contains(
                                      query,
                                    ) ??
                                    false;
                                return nameMatch || descMatch;
                              }).toList())
                        .toList();
                if (_sortBy == 'price_asc')
                  products.sort((a, b) => a.price.compareTo(b.price));
                if (_sortBy == 'price_desc')
                  products.sort((a, b) => b.price.compareTo(a.price));
                if (_sortBy == 'name')
                  products.sort(
                    (a, b) =>
                        a.name.toLowerCase().compareTo(b.name.toLowerCase()),
                  );

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
    key: ValueKey(product.id),
    product: product,
    isGrid: isGrid,
    isPurchased: _purchasedProductIds.contains(product.id),
    cartQuantity: _cartQuantities[product.id] ?? 0,
    onAddToCart: () async {
      await widget.addProductToCart(product, quantity: 1);
      await _refreshCartCount();
    },
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
            customerFeaturesRepository: widget.customerFeaturesRepository,
            isFavorite: _favoriteProductIds.contains(product.id),
            onToggleFavorite: () => _toggleFavorite(product),
            maxAvailableQuantity: product.stock - inCartQty,
            onAddToCart: (p, q) async {
              await widget.addProductToCart(p, quantity: q);
              await _refreshCartCount();
            },
          ),
        ),
      );
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

class _ProductCard extends StatefulWidget {
  const _ProductCard({
    required this.product,
    required this.onTap,
    required this.onAddToCart,
    this.cartQuantity = 0,
    this.isGrid = false,
    this.isPurchased = false,
    super.key,
  });

  final Product product;
  final VoidCallback onTap;
  final Future<void> Function() onAddToCart;
  final int cartQuantity;
  final bool isGrid;
  final bool isPurchased;

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard> {
  bool _isAdding = false;
  bool _justAdded = false;

  Future<void> _addToCart() async {
    if (_isAdding || _justAdded) return;
    setState(() => _isAdding = true);
    try {
      await widget.onAddToCart();
      if (!mounted) return;
      setState(() {
        _isAdding = false;
        _justAdded = true;
      });
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      if (mounted) setState(() => _justAdded = false);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isAdding = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final isGrid = widget.isGrid;
    final isPurchased = widget.isPurchased;
    final cartIcon = _isAdding
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(
            _justAdded ? Icons.check : Icons.add_shopping_cart,
            size: isGrid ? 19 : 24,
          );
    final colors = Theme.of(context).colorScheme;
    final hasStock = product.stockTracked && product.stock > 0;
    final stockLabel = !product.stockTracked
        ? 'Stock sin configurar (${widget.cartQuantity})'
        : hasStock
        ? 'Stock ${product.stock} (${widget.cartQuantity})'
        : 'Agotado (${widget.cartQuantity})';
    final image = product.imageUrl;

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
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
                    if (isPurchased) ...[
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star,
                              size: 11,
                              color: colors.onPrimaryContainer,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'Comprado · Calificar',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: colors.onPrimaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '\$${product.price.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: colors.primary,
                                ),
                              ),
                              Text(
                                stockLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                softWrap: false,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: hasStock
                                      ? colors.onTertiaryContainer
                                      : colors.onErrorContainer,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton.filledTonal(
                          tooltip: 'Agregar al carrito',
                          visualDensity: VisualDensity.compact,
                          onPressed: hasStock && !_isAdding && !_justAdded
                              ? _addToCart
                              : null,
                          icon: cartIcon,
                        ),
                      ],
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
                          if (isPurchased) ...[
                            const SizedBox(height: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colors.primaryContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.star,
                                    size: 13,
                                    color: colors.onPrimaryContainer,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Comprado · Calificar',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: colors.onPrimaryContainer,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
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
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: false,
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
                    const SizedBox(width: 4),
                    IconButton.filledTonal(
                      tooltip: 'Agregar al carrito',
                      onPressed: hasStock && !_isAdding && !_justAdded
                          ? _addToCart
                          : null,
                      icon: cartIcon,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
