import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecommerce_mobile/application/get_products.dart';
import 'package:ecommerce_mobile/application/product_repository.dart';
import 'package:ecommerce_mobile/domain/product.dart';

class FakeProductRepository implements ProductRepository {
  FakeProductRepository({this.products = const [], this.shouldFail = false});

  final List<Product> products;
  final bool shouldFail;

  @override
  Future<List<Product>> getProducts({int? categoryId}) async {
    if (shouldFail) {
      throw const HttpException('Fallo de conexión simulado sin red.');
    }
    if (categoryId != null) {
      return products.where((p) => p.categoryIds.contains(categoryId)).toList();
    }
    return products;
  }

  @override
  Future<Product?> getProduct(int id) async {
    if (shouldFail) {
      throw const HttpException('Fallo de conexión.');
    }
    try {
      return products.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }
}

void main() {
  group('PA-02: Pruebas unitarias móvil / Application (sin red)', () {
    final sampleProducts = [
      const Product(
        id: 7,
        name: 'PROD-TEST-001',
        price: 10.0,
        categoryIds: [1],
      ),
      const Product(
        id: 8,
        name: 'PROD-TEST-002',
        price: 15.0,
        categoryIds: [2],
      ),
    ];

    test('Consultar productos exitosamente devuelve lista desde el caso de uso', () async {
      final fakeRepo = FakeProductRepository(products: sampleProducts);
      final useCase = GetProducts(fakeRepo);

      final result = await useCase();

      expect(result.length, 2);
      expect(result[0].name, 'PROD-TEST-001');
      expect(result[1].name, 'PROD-TEST-002');
    });

    test('Filtrar productos por categoría devuelve únicamente los asociados', () async {
      final fakeRepo = FakeProductRepository(products: sampleProducts);
      final useCase = GetProducts(fakeRepo);

      final result = await useCase(categoryId: 2);

      expect(result.length, 1);
      expect(result.first.id, 8);
    });

    test('Gestionar fallo de repositorio controlado mediante excepción', () async {
      final fakeRepo = FakeProductRepository(shouldFail: true);
      final useCase = GetProducts(fakeRepo);

      expect(() => useCase(), throwsA(isA<HttpException>()));
    });
  });
}
