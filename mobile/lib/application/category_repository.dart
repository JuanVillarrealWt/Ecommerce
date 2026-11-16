import '../domain/category.dart';

abstract interface class CategoryRepository {
  Future<List<Category>> getCategories();
}
