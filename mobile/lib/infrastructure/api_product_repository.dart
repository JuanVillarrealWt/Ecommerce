import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../application/product_repository.dart';
import '../domain/product.dart';
import 'api_config.dart';

class ApiProductRepository implements ProductRepository {
  ApiProductRepository({String? baseUrl})
    : _baseUrl = normalizeApiBaseUrl(baseUrl ?? apiBaseUrl);

  final String _baseUrl;
  static final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 6)
    ..idleTimeout = const Duration(seconds: 30);

  @override
  Future<List<Product>> getProducts({int? categoryId}) async {
    try {
      final uri = categoryId != null && categoryId > 0
          ? Uri.parse('$_baseUrl/api/products?categoryId=$categoryId')
          : Uri.parse('$_baseUrl/api/products');

      final request = await _client
          .getUrl(uri)
          .timeout(const Duration(seconds: 8));
      final response = await request.close().timeout(
        const Duration(seconds: 12),
      );
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'La API respondió con estado ${response.statusCode}.',
        );
      }
      final rows = jsonDecode(body) as List<dynamic>;
      return rows
          .map((row) => _mapProduct(row as Map<String, dynamic>))
          .toList(growable: false);
    } on SocketException catch (error) {
      throw HttpException(
        'No se pudo conectar con la API en $_baseUrl. Verifica que el teléfono y el computador estén en la misma Wi‑Fi, que la IP sea correcta y que la API esté iniciada. ${error.message}',
      );
    } on TimeoutException {
      throw HttpException('La API en $_baseUrl tardó demasiado en responder.');
    }
  }

  @override
  Future<Product?> getProduct(int id) async {
    try {
      final request = await _client
          .getUrl(Uri.parse('$_baseUrl/api/products/$id'))
          .timeout(const Duration(seconds: 8));
      final response = await request.close().timeout(
        const Duration(seconds: 12),
      );
      if (response.statusCode == 404) return null;
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'La API respondió con estado ${response.statusCode}.',
        );
      }
      final json = jsonDecode(body) as Map<String, dynamic>;
      return _mapProduct(json);
    } on SocketException catch (error) {
      throw HttpException(
        'No se pudo conectar con la API en $_baseUrl. ${error.message}',
      );
    } on TimeoutException {
      throw HttpException('La API en $_baseUrl tardó demasiado en responder.');
    }
  }

  Product _mapProduct(Map<String, dynamic> json) {
    final catIds = <int>[];
    if (json['categoryIds'] is List) {
      for (final cid in json['categoryIds'] as List) {
        if (cid is int) catIds.add(cid);
      }
    }
    return Product(
      id: json['id'] as int,
      name: json['name'] as String? ?? 'Producto sin nombre',
      price: (json['price'] as num? ?? 0).toDouble(),
      description: json['description'] as String?,
      imageUrl: _resolveImageUrl(json['imageUrl'] as String?),
      categoryIds: catIds,
      stock: json['stock'] as int? ?? 0,
      stockTracked: json['stockTracked'] as bool? ?? false,
    );
  }

  String? _resolveImageUrl(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) return null;
    if (imageUrl.startsWith('/')) return '$_baseUrl$imageUrl';
    return imageUrl;
  }
}
