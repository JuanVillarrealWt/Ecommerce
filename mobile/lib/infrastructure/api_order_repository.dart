import 'dart:convert';
import 'dart:io';

import '../application/auth_repository.dart';
import '../application/order_repository.dart';
import '../domain/cart_item.dart';
import '../domain/order.dart';

class ApiOrderRepository implements OrderRepository {
  ApiOrderRepository(this._authRepository, {String? baseUrl})
    : _baseUrl =
          (baseUrl ??
                  const String.fromEnvironment(
                    'API_BASE_URL',
                    defaultValue: 'http://10.0.2.2:5000',
                  ))
              .replaceFirst(RegExp(r'/$'), '');

  final AuthRepository _authRepository;
  final String _baseUrl;

  @override
  Future<OrderModel> createOrder(List<CartItem> items) async {
    final token = _authRepository.getAuthToken();
    if (token == null) {
      throw const HttpException('Debe iniciar sesión para confirmar un pedido.');
    }

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
    try {
      final request = await client.postUrl(Uri.parse('$_baseUrl/api/orders'));
      request.headers.contentType = ContentType.json;
      request.headers.set('Authorization', 'Bearer $token');

      final payload = {
        'items': items
            .map((i) => {
                  'productId': i.product.id,
                  'quantity': i.quantity,
                })
            .toList(),
      };
      request.write(jsonEncode(payload));

      final response = await request.close().timeout(const Duration(seconds: 25));
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final err = _extractErrorMessage(body, 'Error al crear pedido (${response.statusCode})');
        throw HttpException(err);
      }

      final json = jsonDecode(body) as Map<String, dynamic>;
      return _mapOrder(json);
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<List<OrderModel>> getCustomerOrders() async {
    final token = _authRepository.getAuthToken();
    if (token == null) {
      return [];
    }

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.getUrl(Uri.parse('$_baseUrl/api/orders'));
      request.headers.set('Authorization', 'Bearer $token');

      final response = await request.close().timeout(const Duration(seconds: 20));
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('No se pudieron recuperar los pedidos (${response.statusCode})');
      }

      final list = jsonDecode(body) as List<dynamic>;
      return list.map((item) => _mapOrder(item as Map<String, dynamic>)).toList();
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<OrderModel?> getOrderDetail(int orderId) async {
    final token = _authRepository.getAuthToken();
    if (token == null) {
      throw const HttpException('Debe iniciar sesión.');
    }

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.getUrl(Uri.parse('$_baseUrl/api/orders/$orderId'));
      request.headers.set('Authorization', 'Bearer $token');

      final response = await request.close().timeout(const Duration(seconds: 20));
      if (response.statusCode == 404) return null;

      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode == 403) {
        throw const HttpException('No tiene autorización para ver este pedido.');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('Error al obtener detalle del pedido (${response.statusCode})');
      }

      final json = jsonDecode(body) as Map<String, dynamic>;
      return _mapOrder(json);
    } finally {
      client.close(force: true);
    }
  }

  OrderModel _mapOrder(Map<String, dynamic> json) {
    final itemsList = <OrderItemModel>[];
    if (json['items'] is List) {
      for (final item in json['items'] as List) {
        final i = item as Map<String, dynamic>;
        itemsList.add(OrderItemModel(
          productId: i['productId'] as int? ?? 0,
          productName: i['productName'] as String? ?? 'Producto',
          quantity: i['quantity'] as int? ?? 1,
          unitPrice: (i['unitPrice'] as num? ?? 0).toDouble(),
          subtotal: (i['subtotal'] as num? ?? 0).toDouble(),
        ));
      }
    }

    return OrderModel(
      id: json['id'] as int,
      name: json['name'] as String? ?? 'Pedido ${json['id']}',
      partnerId: json['partnerId'] as int? ?? 0,
      partnerName: json['partnerName'] as String? ?? 'Consumidor',
      state: json['state'] as String? ?? 'draft',
      amountTotal: (json['amountTotal'] as num? ?? 0).toDouble(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      items: itemsList,
    );
  }

  String _extractErrorMessage(String body, String defaultMessage) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      return json['detail'] as String? ?? json['title'] as String? ?? defaultMessage;
    } catch (_) {
      return defaultMessage;
    }
  }
}
