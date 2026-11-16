import 'product.dart';

class CartItem {
  CartItem({required this.product, required this.quantity}) {
    if (quantity <= 0) {
      throw ArgumentError.value(
        quantity,
        'quantity',
        'Debe ser mayor que cero.',
      );
    }
  }

  final Product product;
  final int quantity;

  double get subtotal => product.price * quantity;

  CartItem withQuantity(int value) =>
      CartItem(product: product, quantity: value);
}
