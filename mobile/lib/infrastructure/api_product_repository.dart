import 'dart:convert';
import 'dart:io';

import '../application/product_repository.dart';
import '../domain/product.dart';

class ApiProductRepository implements ProductRepository {
  ApiProductRepository({String? baseUrl})
    : _baseUrl =
          (baseUrl ??
                  const String.fromEnvironment(
                    'API_BASE_URL',
                    defaultValue: 'http://10.0.2.2:5000',
                  ))
              .replaceFirst(RegExp(r'/$'), '');

  final String _baseUrl;

  @override
  Future<List<Product>> getProducts({int? categoryId}) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final uri = categoryId != null && categoryId > 0
          ? Uri.parse('$_baseUrl/api/products?categoryId=$categoryId')
          : Uri.parse('$_baseUrl/api/products');

      final request = await client.getUrl(uri);
      final response = await request.close().timeout(
        const Duration(seconds: 20),
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
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<Product?> getProduct(int id) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.getUrl(Uri.parse('$_baseUrl/api/products/$id'));
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      if (response.statusCode == 404) return null;
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('La API respondió con estado ${response.statusCode}.');
      }
      final json = jsonDecode(body) as Map<String, dynamic>;
      return _mapProduct(json);
    } finally {
      client.close(force: true);
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
      imageUrl: json['imageUrl'] as String?,
      categoryIds: catIds,
    );
  }
}
