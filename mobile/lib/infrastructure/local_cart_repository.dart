import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../application/cart_repository.dart';
import '../domain/cart.dart';
import '../domain/product.dart';

/// Persists the cart locally. API calls are not involved in reads or writes.
class LocalCartRepository implements CartRepository {
  static const _storageKey = 'ecommerce.cart.v2';
  static const _previousStorageKey = 'ecommerce.cart.v1';

  Cart _cart = Cart.empty();
  Future<void>? _loadFuture;
  Future<SharedPreferences>? _preferencesFuture;
  Future<void> _writeQueue = Future<void>.value();

  Future<SharedPreferences> get _preferences =>
      _preferencesFuture ??= SharedPreferences.getInstance();

  Future<void> _ensureLoaded() => _loadFuture ??= _load();

  Future<void> _load() async {
    final preferences = await _preferences;
    await preferences.remove(_previousStorageKey);
    final stored = preferences.getString(_storageKey);
    if (stored == null || stored.isEmpty) return;

    try {
      final decoded = jsonDecode(stored) as List<dynamic>;
      var restored = Cart.empty();
      for (final entry in decoded) {
        final item = entry as Map<String, dynamic>;
        final productData = item['product'] as Map<String, dynamic>;
        final product = Product(
          id: productData['id'] as int,
          name: productData['name'] as String,
          price: (productData['price'] as num).toDouble(),
          description: productData['description'] as String?,
          imageUrl: productData['imageUrl'] as String?,
          categoryIds:
              (productData['categoryIds'] as List<dynamic>? ?? const [])
                  .cast<int>(),
          stock: productData['stock'] as int? ?? 0,
          stockTracked: productData['stockTracked'] as bool? ?? false,
        );
        final quantity = item['quantity'] as int;
        if (quantity > 0) restored = restored.add(product, quantity: quantity);
      }
      _cart = restored;
    } on Object {
      // Ignore corrupted/older local data; the user can keep using the app.
      _cart = Cart.empty();
    }
  }

  @override
  Future<Cart> getCart() async {
    await _ensureLoaded();
    return _cart;
  }

  @override
  Future<void> save(Cart cart) async {
    await _ensureLoaded();
    _cart = cart;

    final snapshot = jsonEncode([
      for (final item in cart.items)
        {
          'quantity': item.quantity,
          'product': {
            'id': item.product.id,
            'name': item.product.name,
            'price': item.product.price,
            'description': item.product.description,
            'imageUrl': item.product.imageUrl,
            'categoryIds': item.product.categoryIds,
            'stock': item.product.stock,
            'stockTracked': item.product.stockTracked,
          },
        },
    ]);

    // Serialize writes so quick quantity changes cannot leave an older snapshot.
    _writeQueue = _writeQueue.then((_) async {
      final preferences = await _preferences;
      await preferences.setString(_storageKey, snapshot);
    });
    await _writeQueue;
  }
}
