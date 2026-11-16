import 'dart:convert';
import 'dart:io';

import '../application/category_repository.dart';
import '../domain/category.dart';

class ApiCategoryRepository implements CategoryRepository {
  ApiCategoryRepository({String? baseUrl})
    : _baseUrl =
          (baseUrl ??
                  const String.fromEnvironment(
                    'API_BASE_URL',
                    defaultValue: 'http://10.0.2.2:5000',
                  ))
              .replaceFirst(RegExp(r'/$'), '');

  final String _baseUrl;

  @override
  Future<List<Category>> getCategories() async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.getUrl(Uri.parse('$_baseUrl/api/categories'));
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
          .map((row) {
            final json = row as Map<String, dynamic>;
            return Category(
              id: json['id'] as int,
              name: json['name'] as String? ?? 'Categoría',
              parentId: json['parentId'] as int?,
            );
          })
          .toList(growable: false);
    } finally {
      client.close(force: true);
    }
  }
}
