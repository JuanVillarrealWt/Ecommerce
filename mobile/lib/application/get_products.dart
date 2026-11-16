import '../domain/product.dart';
import 'product_repository.dart';

class GetProducts {
  const GetProducts(this._repository);
  final ProductRepository _repository;
  Future<List<Product>> call({int? categoryId}) =>
      _repository.getProducts(categoryId: categoryId);
}

class GetProductDetail {
  const GetProductDetail(this._repository);
  final ProductRepository _repository;
  Future<Product?> call(int id) => _repository.getProduct(id);
}
