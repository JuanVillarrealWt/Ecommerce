class Product {
  const Product({
    required this.id,
    required this.name,
    required this.price,
    this.description,
    this.imageUrl,
    this.categoryIds = const [],
  });

  final int id;
  final String name;
  final double price;
  final String? description;
  final String? imageUrl;
  final List<int> categoryIds;
}
