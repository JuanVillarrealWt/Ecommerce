class Product {
  const Product({
    required this.id,
    required this.name,
    required this.price,
    this.description,
    this.imageUrl,
    this.categoryIds = const [],
    this.stock = 0,
    this.stockTracked = false,
  });

  final int id;
  final String name;
  final double price;
  final String? description;
  final String? imageUrl;
  final List<int> categoryIds;
  final int stock;
  final bool stockTracked;
}
