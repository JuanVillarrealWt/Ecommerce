import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../application/cart_repository.dart';
import '../domain/cart.dart';
import '../domain/cart_item.dart';
import '../domain/product.dart';
import 'api_auth_repository.dart';
import 'api_config.dart';
import 'local_cart_repository.dart';

/// Local-first cache with background synchronization to the authenticated account.
class ApiCartRepository implements CartRepository {
  ApiCartRepository({
    required LocalCartRepository local,
    required ApiAuthRepository auth,
    String? baseUrl,
  }) : _local = local,
       _auth = auth,
       _baseUrl = normalizeApiBaseUrl(baseUrl ?? apiBaseUrl);

  final LocalCartRepository _local;
  final ApiAuthRepository _auth;
  final String _baseUrl;
  Cart? _pendingSnapshot;
  bool _syncing = false;
  bool _initialSyncing = false;
  int? _accountReadyCustomerId;

  @override
  Future<Cart> getCart() {
    final customerId = _auth.getCurrentCustomer()?.id;
    if (customerId != null && _accountReadyCustomerId == customerId) {
      return _local.getAccountCart(customerId);
    }
    return _local.getGuestCart();
  }

  @override
  Future<void> save(Cart cart) async {
    final customerId = _auth.getCurrentCustomer()?.id;
    final token = _auth.getAuthToken();
    if (customerId == null ||
        token == null ||
        _accountReadyCustomerId != customerId ||
        _initialSyncing) {
      await _local.saveGuestCart(cart);
      return;
    }
    await _local.saveAccountCart(customerId, cart);
    _pendingSnapshot = cart;
    unawaited(_drainPendingWrites());
  }

  /// Merges the guest cart with the signed-in customer's cart, then persists
  /// the result both remotely and in the customer's device-specific cache.
  Future<void> syncFromAccount() async {
    final token = _auth.getAuthToken();
    final customerId = _auth.getCurrentCustomer()?.id;
    if (token == null || customerId == null) return;
    _initialSyncing = true;
    _accountReadyCustomerId = null;
    _pendingSnapshot = null;
    try {
      final response = await _send(HttpMethod.get, token: token);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          _errorMessage(response.body, 'No se pudo sincronizar el carrito.'),
        );
      }

      final accountCart = _cartFromPayload(response.body);
      // Read guest data after the request so products added while the API call
      // was in progress are included as well.
      final guestCart = await _local.getGuestCart();
      final merged = accountCart.mergedWith(guestCart);
      final saved = await _send(
        HttpMethod.put,
        token: token,
        body: _encodeCart(merged),
      );
      if (saved.statusCode < 200 || saved.statusCode >= 300) {
        throw HttpException(
          _errorMessage(saved.body, 'No se pudo guardar el carrito combinado.'),
        );
      }

      await _local.saveAccountCart(customerId, merged);
      await _local.clearGuestCart();
      _accountReadyCustomerId = customerId;
    } finally {
      _initialSyncing = false;
    }
  }

  Cart _cartFromPayload(String body) {
    final payload = jsonDecode(body) as Map<String, dynamic>;
    final restored = <CartItem>[];
    for (final entry in payload['items'] as List<dynamic>? ?? const []) {
      final item = entry as Map<String, dynamic>;
      final product = Product(
        id: item['productId'] as int,
        name: item['productName'] as String? ?? 'Producto',
        price: (item['unitPrice'] as num? ?? 0).toDouble(),
        description: item['description'] as String?,
        imageUrl: _resolveImageUrl(item['imageUrl'] as String?),
        categoryIds: (item['categoryIds'] as List<dynamic>? ?? const [])
            .cast<int>(),
        stock: item['stock'] as int? ?? 0,
        stockTracked: item['stockTracked'] as bool? ?? false,
      );
      final quantity = item['quantity'] as int? ?? 1;
      if (quantity > 0) {
        restored.add(CartItem(product: product, quantity: quantity));
      }
    }
    return Cart.fromItems(restored);
  }

  String _encodeCart(Cart cart) => jsonEncode({
    'items': [
      for (final item in cart.items)
        {
          'productId': item.product.id,
          'quantity': item.quantity,
          'productName': item.product.name,
          'unitPrice': item.product.price,
          'description': item.product.description,
          'imageUrl': _relativeImageUrl(item.product.imageUrl),
          'categoryIds': item.product.categoryIds,
          'stock': item.product.stock,
          'stockTracked': item.product.stockTracked,
        },
    ],
  });

  Future<void> _drainPendingWrites() async {
    if (_syncing) return;
    _syncing = true;
    Cart? inFlight;
    try {
      while (_pendingSnapshot != null) {
        final snapshot = _pendingSnapshot!;
        inFlight = snapshot;
        _pendingSnapshot = null;
        final token = _auth.getAuthToken();
        final customerId = _auth.getCurrentCustomer()?.id;
        if (token == null ||
            customerId == null ||
            _accountReadyCustomerId != customerId)
          return;
        final response = await _send(
          HttpMethod.put,
          token: token,
          body: _encodeCart(snapshot),
        );
        if (response.statusCode < 200 || response.statusCode >= 300) {
          _pendingSnapshot ??= snapshot;
          return;
        }
        inFlight = null;
      }
    } on Object {
      // Keep the latest snapshot for the next edit or successful account sync.
      if (inFlight != null) _pendingSnapshot ??= inFlight;
      return;
    } finally {
      _syncing = false;
    }
  }

  Future<_ApiResponse> _send(
    HttpMethod method, {
    required String token,
    String? body,
  }) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final uri = Uri.parse('$_baseUrl/api/cart');
      final request = method == HttpMethod.get
          ? await client.getUrl(uri)
          : await client.putUrl(uri);
      request.headers.set('Authorization', 'Bearer $token');
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(body);
      }
      final response = await request.close().timeout(
        const Duration(seconds: 10),
      );
      final responseBody = await response.transform(utf8.decoder).join();
      return _ApiResponse(response.statusCode, responseBody);
    } finally {
      client.close(force: true);
    }
  }

  String _errorMessage(String body, String fallback) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      return data['detail'] as String? ?? data['title'] as String? ?? fallback;
    } catch (_) {
      return fallback;
    }
  }

  String? _resolveImageUrl(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) return null;
    if (imageUrl.startsWith('/')) return '$_baseUrl$imageUrl';
    return imageUrl;
  }

  String? _relativeImageUrl(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) return null;
    final imageUri = Uri.tryParse(imageUrl);
    final apiUri = Uri.tryParse(_baseUrl);
    if (imageUri != null &&
        apiUri != null &&
        imageUri.hasAuthority &&
        imageUri.origin == apiUri.origin) {
      final path = imageUri.path;
      return imageUri.hasQuery ? '$path?${imageUri.query}' : path;
    }
    return imageUrl;
  }
}

enum HttpMethod { get, put }

class _ApiResponse {
  const _ApiResponse(this.statusCode, this.body);
  final int statusCode;
  final String body;
}
