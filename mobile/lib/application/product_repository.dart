import '../domain/product.dart';

abstract interface class ProductRepository {
  Future<List<Product>> getProducts({int? categoryId});
  Future<Product?> getProduct(int id);
}
