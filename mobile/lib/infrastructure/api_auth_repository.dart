import 'dart:convert';
import 'dart:io';

import '../application/auth_repository.dart';
import '../domain/customer.dart';
import 'api_config.dart';

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository({String? baseUrl})
    : _baseUrl = normalizeApiBaseUrl(baseUrl ?? apiBaseUrl);

  final String _baseUrl;
  Customer? _currentCustomer;
  String? _authToken;

  @override
  Customer? getCurrentCustomer() => _currentCustomer;

  @override
  String? getAuthToken() => _authToken;

  @override
  bool get isAuthenticated => _authToken != null && _currentCustomer != null;

  @override
  Future<Customer> register(String name, String email, String password, String province, String phone) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.postUrl(Uri.parse('$_baseUrl/api/auth/register'));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        'province': province,
        'phone': phone,
      }));

      final response = await request.close().timeout(const Duration(seconds: 20));
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final err = _extractErrorMessage(body, 'Error al registrar cliente (${response.statusCode})');
        throw HttpException(err);
      }

      // Auto-login tras registro
      return await login(email, password);
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<Customer> login(String email, String password) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.postUrl(Uri.parse('$_baseUrl/api/auth/login'));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({
        'email': email,
        'password': password,
      }));

      final response = await request.close().timeout(const Duration(seconds: 20));
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final err = _extractErrorMessage(body, 'Credenciales inválidas.');
        throw HttpException(err);
      }

      final json = jsonDecode(body) as Map<String, dynamic>;
      _authToken = json['token'] as String;

      final custJson = json['customer'] as Map<String, dynamic>;
      _currentCustomer = Customer(
        id: custJson['id'] as int,
        name: custJson['name'] as String,
        email: custJson['email'] as String,
        partnerId: custJson['partnerId'] as int,
        province: custJson['province'] as String? ?? '',
        phone: custJson['phone'] as String? ?? '',
      );

      return _currentCustomer!;
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<void> logout() async {
    _currentCustomer = null;
    _authToken = null;
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

