import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../application/category_repository.dart';
import '../domain/category.dart';
import 'api_config.dart';

class ApiCategoryRepository implements CategoryRepository {
  ApiCategoryRepository({String? baseUrl})
    : _baseUrl = normalizeApiBaseUrl(baseUrl ?? apiBaseUrl);

  final String _baseUrl;

  @override
  Future<List<Category>> getCategories() async {
    final client = _client;
    try {
      final request = await client.getUrl(Uri.parse('$_baseUrl/api/categories'));
      final response = await request.close().timeout(const Duration(seconds: 12));
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'La API respondió con estado ${response.statusCode}.',
        );
      }
      final rows = jsonDecode(body) as List<dynamic>;
      return rows
          .map((row) {
            final json = row as Map<String, dynamic>;
            return Category(
              id: json['id'] as int,
              name: json['name'] as String? ?? 'Categoría',
              parentId: json['parentId'] as int?,
            );
          })
          .toList(growable: false);
    } on SocketException catch (error) {
      throw HttpException('No se pudo conectar con la API en $_baseUrl. Verifica la red y la dirección de la API. ${error.message}');
    } on TimeoutException {
      throw HttpException('La API en $_baseUrl tardó demasiado en responder.');
    }
  }

  static final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 6)
    ..idleTimeout = const Duration(seconds: 30);
}

