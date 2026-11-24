import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../application/auth_repository.dart';
import '../application/checkout_repository.dart';
import '../domain/cart_item.dart';
import '../domain/checkout_payment.dart';
import 'api_config.dart';

class ApiCheckoutRepository implements CheckoutRepository {
  ApiCheckoutRepository(this._authRepository, {String? baseUrl})
    : _baseUrl = normalizeApiBaseUrl(baseUrl ?? apiBaseUrl);

  final AuthRepository _authRepository;
  final String _baseUrl;

  @override
  Future<CheckoutPayment> startCheckout(
    List<CartItem> items, {
    String? couponCode,
    String? savedAddressId,
  }) async {
    final token = _authRepository.getAuthToken();
    if (token == null) throw const HttpException('Inicia sesión para pagar.');
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      final request = await client.postUrl(
        Uri.parse('$_baseUrl/api/checkout/payments'),
      );
      request.headers.contentType = ContentType.json;
      request.headers.set('Authorization', 'Bearer $token');
      request.write(
        jsonEncode({
          'items': items
              .map(
                (item) => {
                  'productId': item.product.id,
                  'quantity': item.quantity,
                },
              )
              .toList(),
          if (couponCode != null && couponCode.trim().isNotEmpty)
            'couponCode': couponCode.trim(),
          if (savedAddressId != null && savedAddressId.isNotEmpty)
            'savedAddressId': savedAddressId,
        }),
      );
      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(_errorMessage(body, 'No se pudo iniciar el pago.'));
      }
      return CheckoutPayment.fromJson(jsonDecode(body) as Map<String, dynamic>);
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<CheckoutPaymentStatus> getStatus(String attemptId) async {
    final token = _authRepository.getAuthToken();
    if (token == null) {
      throw const HttpException('La sesión expiró. Inicia sesión nuevamente.');
    }
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.getUrl(
        Uri.parse('$_baseUrl/api/checkout/payments/$attemptId'),
      );
      request.headers.set('Authorization', 'Bearer $token');
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          _errorMessage(body, 'No se pudo consultar el pago.'),
        );
      }
      return CheckoutPaymentStatus.fromJson(
        jsonDecode(body) as Map<String, dynamic>,
      );
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<String> prepareConfirmation(String attemptId) async {
    final token = _authRepository.getAuthToken();
    if (token == null) {
      throw const HttpException('La sesión expiró. Inicia sesión nuevamente.');
    }
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.postUrl(
        Uri.parse('$_baseUrl/api/checkout/payments/$attemptId/confirmation'),
      );
      request.headers.set('Authorization', 'Bearer $token');
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          _errorMessage(body, 'No se pudo preparar la confirmación del pago.'),
        );
      }
      return (jsonDecode(body) as Map<String, dynamic>)['clientSecret']
          as String;
    } finally {
      client.close(force: true);
    }
  }

  String _errorMessage(String body, String fallback) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      return json['detail'] as String? ?? json['title'] as String? ?? fallback;
    } catch (_) {
      return fallback;
    }
  }
}
