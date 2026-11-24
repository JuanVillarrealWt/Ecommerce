import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../application/cart_repository.dart';
import '../domain/cart.dart';
import '../domain/cart_item.dart';
import '../domain/product.dart';

/// Persists the cart locally. API calls are not involved in reads or writes.
class LocalCartRepository implements CartRepository {
  static const _guestStorageKey = 'ecommerce.cart.guest.v1';
  static const _legacyStorageKey = 'ecommerce.cart.v2';
  static const _previousStorageKey = 'ecommerce.cart.v1';

  Future<SharedPreferences>? _preferencesFuture;
  Future<void> _writeQueue = Future<void>.value();

  Future<SharedPreferences> get _preferences =>
      _preferencesFuture ??= SharedPreferences.getInstance();

  Future<Cart> _readCart(String storageKey) async {
    final preferences = await _preferences;
    final stored = preferences.getString(storageKey);
    if (stored == null || stored.isEmpty) return Cart.empty();

    try {
      final decoded = jsonDecode(stored) as List<dynamic>;
      final restored = <CartItem>[];
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
        if (quantity > 0) {
          restored.add(CartItem(product: product, quantity: quantity));
        }
      }
      return Cart.fromItems(restored);
    } on Object {
      // Ignore corrupted/older local data; the user can keep using the app.
      return Cart.empty();
    }
  }

  String _accountStorageKey(int customerId) =>
      'ecommerce.cart.account.$customerId.v1';

  Future<void> _migrateLegacyGuestCart() async {
    final preferences = await _preferences;
    if (preferences.containsKey(_guestStorageKey)) return;
    final legacy = preferences.getString(_legacyStorageKey);
    if (legacy != null && legacy.isNotEmpty) {
      await preferences.setString(_guestStorageKey, legacy);
    }
    await preferences.remove(_legacyStorageKey);
    await preferences.remove(_previousStorageKey);
  }

  Future<Cart> getGuestCart() async {
    await _migrateLegacyGuestCart();
    return _readCart(_guestStorageKey);
  }

  Future<void> saveGuestCart(Cart cart) => _saveCart(_guestStorageKey, cart);

  Future<Cart> getAccountCart(int customerId) =>
      _readCart(_accountStorageKey(customerId));

  Future<void> saveAccountCart(int customerId, Cart cart) =>
      _saveCart(_accountStorageKey(customerId), cart);

  Future<void> clearGuestCart() async {
    await _saveCart(_guestStorageKey, Cart.empty());
  }

  @override
  Future<Cart> getCart() => getGuestCart();

  @override
  Future<void> save(Cart cart) => saveGuestCart(cart);

  Future<void> _saveCart(String storageKey, Cart cart) async {
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
      await preferences.setString(storageKey, snapshot);
    });
    await _writeQueue;
  }
}
