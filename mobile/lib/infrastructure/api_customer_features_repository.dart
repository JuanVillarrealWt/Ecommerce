import 'dart:convert';
import 'dart:io';

import '../application/auth_repository.dart';
import '../application/customer_features_repository.dart';
import 'api_config.dart';

class ApiCustomerFeaturesRepository implements CustomerFeaturesRepository {
  ApiCustomerFeaturesRepository(this._auth, {String? baseUrl})
    : _baseUrl = normalizeApiBaseUrl(baseUrl ?? apiBaseUrl);

  final AuthRepository _auth;
  final String _baseUrl;

  Future<dynamic> _request(String method, String path, [Object? body]) async {
    final token = _auth.getAuthToken();
    if (token == null)
      throw const HttpException('Inicia sesión para usar esta función.');
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.openUrl(
        method,
        Uri.parse('$_baseUrl/api/customer/features$path'),
      );
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }
      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      final text = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        var message = 'No se pudo guardar el cambio (${response.statusCode}).';
        try {
          final json = jsonDecode(text);
          if (json is Map)
            message =
                json['detail']?.toString() ??
                json['title']?.toString() ??
                message;
        } catch (_) {}
        throw HttpException(message);
      }
      return text.isEmpty ? null : jsonDecode(text);
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<Map<String, dynamic>> load() async =>
      Map<String, dynamic>.from(await _request('GET', '') as Map);

  @override
  Future<void> addFavorite(int productId) async {
    await _request('POST', '/favorites/$productId');
  }

  @override
  Future<void> removeFavorite(int productId) async {
    await _request('DELETE', '/favorites/$productId');
  }

  @override
  Future<Map<String, dynamic>> saveAddress(
    Map<String, dynamic> address,
  ) async => Map<String, dynamic>.from(
    await _request('POST', '/addresses', address) as Map,
  );

  @override
  Future<Map<String, dynamic>> updateAddress(
    String id,
    Map<String, dynamic> address,
  ) async {
    final result = await _request('PUT', '/addresses/$id', address);
    if (result is Map) return Map<String, dynamic>.from(result);
    return {...address, 'id': id};
  }

  @override
  Future<void> deleteAddress(String id) async {
    await _request('DELETE', '/addresses/$id');
  }

  @override
  Future<void> markNotificationRead(String id) async {
    await _request('POST', '/notifications/$id/read');
  }

  @override
  Future<List<Map<String, dynamic>>> paymentHistory() async {
    final token = _auth.getAuthToken();
    if (token == null)
      throw const HttpException('Inicia sesión para consultar tus pagos.');
    final client = HttpClient();
    try {
      final request = await client.getUrl(
        Uri.parse('$_baseUrl/api/payments/history'),
      );
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      final response = await request.close();
      final text = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300)
        throw HttpException('No se pudo consultar el historial de pagos.');
      return (jsonDecode(text) as List).cast<Map<String, dynamic>>();
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<void> submitReview({
    required int productId,
    required int orderId,
    required int rating,
    required String comment,
  }) async {
    await _request('POST', '/reviews', {
      'productId': productId,
      'orderId': orderId,
      'rating': rating,
      'comment': comment,
    });
  }

  @override
  Future<int?> reviewOrderId(int productId) async {
    final value = await _request('GET', '/products/$productId/review-order');
    return (value as num?)?.toInt();
  }

  @override
  Future<void> deleteReview(int productId) async {
    await _request('DELETE', '/reviews/$productId');
  }

  @override
  Future<List<Map<String, dynamic>>> productReviews(int productId) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(
        Uri.parse(
          '$_baseUrl/api/customer/features/products/$productId/reviews',
        ),
      );
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) return [];
      return (jsonDecode(await response.transform(utf8.decoder).join()) as List)
          .cast<Map<String, dynamic>>();
    } finally {
      client.close(force: true);
    }
  }
}
