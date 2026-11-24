import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

import '../application/auth_repository.dart';
import '../domain/customer.dart';
import 'api_config.dart';

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository({String? baseUrl})
    : _baseUrl = normalizeApiBaseUrl(baseUrl ?? apiBaseUrl);

  final String _baseUrl;
  Customer? _currentCustomer;
  String? _authToken;

  static const _tokenKey = 'auth_token';
  static const _customerKey = 'auth_customer';

  @override
  Future<void> restoreSession() async {
    final preferences = await SharedPreferences.getInstance();
    final token = preferences.getString(_tokenKey);
    final encodedCustomer = preferences.getString(_customerKey);
    if (token == null || encodedCustomer == null) return;
    try {
      final data = jsonDecode(encodedCustomer) as Map<String, dynamic>;
      _authToken = token;
      _currentCustomer = Customer(
        id: data['id'] as int,
        name: data['name'] as String,
        email: data['email'] as String,
        partnerId: data['partnerId'] as int,
        province: data['province'] as String? ?? '',
        phone: data['phone'] as String? ?? '',
      );
    } catch (_) {
      _authToken = null;
      _currentCustomer = null;
      await preferences.remove(_tokenKey);
      await preferences.remove(_customerKey);
    }
  }

  Future<void> _persistSession() async {
    final customer = _currentCustomer;
    final token = _authToken;
    if (customer == null || token == null) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_tokenKey, token);
    await preferences.setString(
      _customerKey,
      jsonEncode({
        'id': customer.id,
        'name': customer.name,
        'email': customer.email,
        'partnerId': customer.partnerId,
        'province': customer.province,
        'phone': customer.phone,
      }),
    );
  }

  @override
  Customer? getCurrentCustomer() => _currentCustomer;

  @override
  String? getAuthToken() => _authToken;

  @override
  bool get isAuthenticated => _authToken != null && _currentCustomer != null;

  @override
  Future<Customer> register(
    String name,
    String email,
    String password,
    String province,
    String phone,
  ) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.postUrl(
        Uri.parse('$_baseUrl/api/auth/register'),
      );
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode({
          'name': name,
          'email': email,
          'password': password,
          'province': province,
          'phone': phone,
        }),
      );

      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final err = _extractErrorMessage(
          body,
          'Error al registrar cliente (${response.statusCode})',
        );
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
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.postUrl(
        Uri.parse('$_baseUrl/api/auth/login'),
      );
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'email': email, 'password': password}));

      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
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
      await _persistSession();

      return _currentCustomer!;
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<Customer> updateProfile(
    String name,
    String province,
    String phone,
  ) async {
    final token = _authToken;
    if (token == null)
      throw const HttpException('Inicia sesión para editar tu perfil.');
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.putUrl(
        Uri.parse('$_baseUrl/api/auth/profile'),
      );
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      request.write(
        jsonEncode({'name': name, 'province': province, 'phone': phone}),
      );
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300)
        throw HttpException(
          _extractErrorMessage(body, 'No se pudo actualizar el perfil.'),
        );
      final json = jsonDecode(body) as Map<String, dynamic>;
      _currentCustomer = Customer(
        id: json['id'] as int,
        name: json['name'] as String,
        email: json['email'] as String,
        partnerId: json['partnerId'] as int,
        province: json['province'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
      );
      await _persistSession();
      return _currentCustomer!;
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<void> logout() async {
    _currentCustomer = null;
    _authToken = null;
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_tokenKey);
    await preferences.remove(_customerKey);
  }

  String _extractErrorMessage(String body, String defaultMessage) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      return json['detail'] as String? ??
          json['title'] as String? ??
          defaultMessage;
    } catch (_) {
      return defaultMessage;
    }
  }
}
