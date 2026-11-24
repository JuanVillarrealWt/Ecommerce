import 'package:flutter/material.dart';

import '../application/cart_use_cases.dart';
import '../application/customer_features_repository.dart';
import '../application/get_products.dart';
import '../domain/product.dart';
import 'product_detail_page.dart';
import 'product_image.dart';
import 'address_form_page.dart';

class CustomerFeaturesPage extends StatefulWidget {
  const CustomerFeaturesPage({
    required this.repository,
    required this.getProductDetail,
    required this.getCart,
    required this.addProductToCart,
    required this.onCartChanged,
    this.initialProvince = '',
    this.initialPhone = '',
    this.onBack,
    super.key,
  });
  final CustomerFeaturesRepository repository;
  final GetProductDetail getProductDetail;
  final GetCart getCart;
  final AddProductToCart addProductToCart;
  final VoidCallback onCartChanged;
  final String initialProvince;
  final String initialPhone;
  final VoidCallback? onBack;

  @override
  State<CustomerFeaturesPage> createState() => _CustomerFeaturesPageState();
}

class _CustomerFeaturesPageState extends State<CustomerFeaturesPage> {
  late Future<Map<String, dynamic>> _data;
  final Map<int, Future<Product?>> _favoriteProductFutures = {};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _data = widget.repository.load();
  }

  Future<void> _addressDialog({Map? address}) async {
    final useRegistrationData = address == null && await _hasNoAddresses();
    final savedAddress = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => AddressFormPage(
          repository: widget.repository,
          initialProvince: useRegistrationData ? widget.initialProvince : '',
          initialPhone: useRegistrationData ? widget.initialPhone : '',
          initialAddress: address == null
              ? null
              : Map<String, dynamic>.from(address),
          isPrimary: address?['isDefault'] == true,
        ),
      ),
    );
    if (savedAddress != null && mounted) {
      final current = await _data;
      final latest = Map<String, dynamic>.from(current);
      var addresses = (current['addresses'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      if (savedAddress['isDefault'] == true) {
        addresses = addresses
            .map((item) => {...item, 'isDefault': false})
            .toList();
      }
      final index = addresses.indexWhere(
        (item) => '${item['id']}' == '${savedAddress['id']}',
      );
      if (index < 0) {
        addresses.add(savedAddress);
      } else {
        addresses[index] = savedAddress;
      }
      latest['addresses'] = addresses;
      setState(() { _data = Future.value(latest); });
    }
  }

  Future<bool> _hasNoAddresses() async {
    final data = await widget.repository.load();
    return (data['addresses'] as List? ?? const []).isEmpty;
  }

  Future<Product?> _favoriteProduct(int id) => _favoriteProductFutures
      .putIfAbsent(id, () => widget.getProductDetail(id));

  Future<void> _openFavoriteProduct(
    Product product, {
    bool isFavorite = true,
  }) async {
    final cart = await widget.getCart();
    if (!mounted) return;
    final inCart = cart.items
        .where((item) => item.product.id == product.id)
        .fold<int>(0, (sum, item) => sum + item.quantity);
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ProductDetailPage(
          product: product,
          maxAvailableQuantity: product.stock - inCart,
          isFavorite: isFavorite,
          customerFeaturesRepository: widget.repository,
          onToggleFavorite: () async {
            if (isFavorite) {
              await widget.repository.removeFavorite(product.id);
            } else {
              await widget.repository.addFavorite(product.id);
            }
            if (mounted) setState(_reload);
            return true;
          },
          onAddToCart: (item, quantity) async {
            await widget.addProductToCart(item, quantity: quantity);
            widget.onCartChanged();
          },
        ),
      ),
    );
    if (mounted) setState(_reload);
  }

  Widget _reviewTile(Map review) => FutureBuilder<Product?>(
    future: _favoriteProduct(review['productId'] as int),
    builder: (context, snapshot) {
      final product = snapshot.data;
      return ListTile(
        leading: product == null
            ? const CircleAvatar(child: Icon(Icons.inventory_2_outlined))
            : SizedBox(
                width: 52,
                height: 52,
                child: ProductImage(
                  imageUrl: product.imageUrl,
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                ),
              ),
        title: Text(
          product?.name ??
              (snapshot.connectionState == ConnectionState.waiting
                  ? 'Cargando producto…'
                  : 'Producto ${review['productId']}'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text('${review['rating']}/5 · ${review['comment']}'),
        trailing: IconButton(
          tooltip: 'Eliminar reseña',
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _deleteReview((review['productId'] as num).toInt()),
        ),
        onTap: product == null
            ? null
            : () => _openFavoriteProduct(product, isFavorite: false),
      );
    },
  );

  Future<void> _deleteReview(int productId) async {
    if (!await _confirmDelete(
      'Eliminar reseña',
      '¿Quieres eliminar tu calificación y comentario?',
    )) {
      return;
    }
    try {
      final current = await _data;
      final latest = Map<String, dynamic>.from(current);
      final reviews = (current['reviews'] as List? ?? const [])
          .whereType<Map>()
          .where((item) => (item['productId'] as num?)?.toInt() != productId)
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      latest['reviews'] = reviews;
      setState(() {
        _data = Future.value(latest);
      });
      await widget.repository.deleteReview(productId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reseña eliminada.')),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(_reload);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error')),
        );
      }
    }
  }

  Future<void> _deleteAddress(Map address) async {
    final id = '${address['id']}';
    if (!await _confirmDelete(
      'Eliminar dirección',
      '¿Quieres eliminar esta dirección guardada?',
    )) {
      return;
    }
    try {
      final current = await _data;
      final latest = Map<String, dynamic>.from(current);
      final addresses = (current['addresses'] as List? ?? const [])
          .whereType<Map>()
          .where((item) => '${item['id']}' != id)
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      latest['addresses'] = addresses;
      setState(() {
        _data = Future.value(latest);
      });
      await widget.repository.deleteAddress(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dirección eliminada.')),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(_reload);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error')),
        );
      }
    }
  }

  Future<bool> _confirmDelete(
    String title,
    String message, {
    String confirmLabel = 'Eliminar',
  }) async =>
      (await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(confirmLabel),
            ),
          ],
        ),
      )) ??
      false;

  Future<void> _removeFavorite(int productId) async {
    if (!await _confirmDelete(
      'Quitar de favoritos',
      '¿Quieres quitar este producto de tus favoritos?',
      confirmLabel: 'Quitar',
    )) {
      return;
    }
    try {
      await widget.repository.removeFavorite(productId);
      if (!mounted) return;
      final current = await _data;
      final latest = Map<String, dynamic>.from(current);
      latest['favoriteProductIds'] =
          (current['favoriteProductIds'] as List? ?? const [])
              .where((id) => id != productId)
              .toList();
      setState(() {
        _favoriteProductFutures.remove(productId);
        _data = Future.value(latest);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Producto quitado de favoritos.')),
      );
    } catch (_) {
      if (!mounted) return;
      await _reconcileFavoriteRemoval(productId);
    }
  }

  Future<void> _reconcileFavoriteRemoval(int productId) async {
    try {
      final latest = await widget.repository.load();
      if (!mounted) return;
      setState(() { _data = Future.value(latest); });
      final stillFavorite = (latest['favoriteProductIds'] as List? ?? const [])
          .contains(productId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            stillFavorite
                ? 'No se pudo quitar el producto. Intenta de nuevo.'
                : 'Producto quitado de favoritos.',
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo actualizar favoritos. Revisa tu conexión.',
            ),
          ),
        );
      }
    }
  }

  Widget _favoriteTile(int productId) => FutureBuilder<Product?>(
    future: _favoriteProduct(productId),
    builder: (context, snapshot) {
      final product = snapshot.data;
      return ListTile(
        leading: product == null
            ? const CircleAvatar(child: Icon(Icons.inventory_2_outlined))
            : SizedBox(
                width: 52,
                height: 52,
                child: ProductImage(
                  imageUrl: product.imageUrl,
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                ),
              ),
        title: Text(
          product?.name ??
              (snapshot.connectionState == ConnectionState.waiting
                  ? 'Cargando producto…'
                  : 'Producto #$productId'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: product == null
            ? null
            : Text('\$${product.price.toStringAsFixed(2)}'),
        onTap: product == null ? null : () => _openFavoriteProduct(product),
        trailing: IconButton(
          tooltip: 'Quitar de favoritos',
          icon: const Icon(Icons.favorite, color: Colors.pink),
          onPressed: () => _removeFavorite(productId),
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Mis preferencias'),
      leading: widget.onBack == null
          ? null
          : IconButton(
              tooltip: 'Volver al perfil',
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back),
            ),
      actions: [
        IconButton(
          onPressed: () => setState(_reload),
          icon: const Icon(Icons.refresh),
          tooltip: 'Actualizar',
        ),
      ],
    ),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('${snapshot.error}', textAlign: TextAlign.center),
            ),
          );
        }
        final data = snapshot.data ?? {};
        final favorites = (data['favoriteProductIds'] as List? ?? [])
            .cast<int>()
            .toList();
        final addresses = (data['addresses'] as List? ?? []).cast<Map>();
        final notifications = (data['notifications'] as List? ?? [])
            .cast<Map>();
        final reviews = (data['reviews'] as List? ?? []).cast<Map>();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _section('Productos favoritos', Icons.favorite_outline, [
              if (favorites.isEmpty)
                const ListTile(
                  title: Text('Aún no guardas productos favoritos.'),
                ),
              for (final id in favorites) _favoriteTile(id),
            ]),
            _section('Direcciones guardadas', Icons.location_on_outlined, [
              for (final address in addresses)
                ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text('${address['label']} · ${address['recipient']}'),
                  subtitle: Text(
                    '${address['street']}, ${address['city']}, ${address['province']}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (address['isDefault'] == true)
                        const Icon(Icons.check_circle, color: Colors.green),
                      IconButton(
                        tooltip: 'Editar dirección',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _addressDialog(address: address),
                      ),
                      if (address['isDefault'] != true)
                        IconButton(
                          tooltip: 'Eliminar dirección',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deleteAddress(address),
                        ),
                    ],
                  ),
                ),
              if (addresses.isEmpty)
                const ListTile(
                  title: Text(
                    'Guarda una dirección para agilizar tus compras.',
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _addressDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar dirección'),
                ),
              ),
            ]),
            _section('Avisos de pedidos', Icons.notifications_outlined, [
              if (notifications.isEmpty)
                const ListTile(
                  title: Text('Aquí aparecerán novedades de tus pedidos.'),
                ),
              for (final note in notifications)
                ListTile(
                  leading: Icon(
                    note['isRead'] == true
                        ? Icons.notifications_none
                        : Icons.notifications_active_outlined,
                  ),
                  title: Text('${note['title']}'),
                  subtitle: Text('${note['message']}'),
                  onTap: note['isRead'] == true
                      ? null
                      : () async {
                          await widget.repository.markNotificationRead(
                            '${note['id']}',
                          );
                          if (mounted) setState(_reload);
                        },
                ),
            ]),
            _section('Mis reseñas', Icons.star_outline, [
              if (reviews.isEmpty)
                const ListTile(title: Text('Aún no has reseñado productos.')),
              for (final review in reviews) _reviewTile(review),
            ]),
          ],
        );
      },
    ),
  );

  Widget _section(String title, IconData icon, List<Widget> children) => Card(
    margin: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        ...children,
      ],
    ),
  );
}
