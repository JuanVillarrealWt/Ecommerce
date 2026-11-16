import '../domain/cart.dart';
import '../domain/product.dart';
import 'cart_repository.dart';

class GetCart {
  const GetCart(this._repository);
  final CartRepository _repository;
  Future<Cart> call() => _repository.getCart();
}

class AddProductToCart {
  const AddProductToCart(this._repository);
  final CartRepository _repository;
  Future<Cart> call(Product product, {int quantity = 1}) async {
    final cart = (await _repository.getCart()).add(product, quantity: quantity);
    await _repository.save(cart);
    return cart;
  }
}

class SetCartQuantity {
  const SetCartQuantity(this._repository);
  final CartRepository _repository;
  Future<Cart> call(int productId, int quantity) async {
    final cart = (await _repository.getCart()).setQuantity(productId, quantity);
    await _repository.save(cart);
    return cart;
  }
}

class RemoveProductFromCart {
  const RemoveProductFromCart(this._repository);
  final CartRepository _repository;
  Future<Cart> call(int productId) async {
    final cart = (await _repository.getCart()).remove(productId);
    await _repository.save(cart);
    return cart;
  }
}

class ClearCart {
  const ClearCart(this._repository);
  final CartRepository _repository;
  Future<Cart> call() async {
    final cart = (await _repository.getCart()).clear();
    await _repository.save(cart);
    return cart;
  }
}
