import '../application/cart_repository.dart';
import '../domain/cart.dart';

class InMemoryCartRepository implements CartRepository {
  Cart _cart = Cart.empty();

  @override
  Future<Cart> getCart() async => _cart;

  @override
  Future<void> save(Cart cart) async => _cart = cart;
}
