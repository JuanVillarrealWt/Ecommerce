import '../domain/cart.dart';

abstract interface class CartRepository {
  Future<Cart> getCart();
  Future<void> save(Cart cart);
}
