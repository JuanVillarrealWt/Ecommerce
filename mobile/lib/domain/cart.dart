import 'cart_item.dart';
import 'product.dart';

/// Carrito orientativo: el servidor vuelve a validar precios y disponibilidad al confirmar.
class Cart {
  Cart._(this._items);

  factory Cart.empty() => Cart._(const {});

  final Map<int, CartItem> _items;

  List<CartItem> get items => List.unmodifiable(_items.values);
  double get subtotal =>
      _items.values.fold(0, (sum, item) => sum + item.subtotal);
  bool get isEmpty => _items.isEmpty;

  Cart add(Product product, {int quantity = 1}) {
    if (quantity <= 0) {
      throw ArgumentError.value(
        quantity,
        'quantity',
        'Debe ser mayor que cero.',
      );
    }
    final updated = Map<int, CartItem>.of(_items);
    final current = updated[product.id];
    updated[product.id] = CartItem(
      product: product,
      quantity: (current?.quantity ?? 0) + quantity,
    );
    return Cart._(Map.unmodifiable(updated));
  }

  Cart setQuantity(int productId, int quantity) {
    if (quantity <= 0) {
      throw ArgumentError.value(
        quantity,
        'quantity',
        'Debe ser mayor que cero.',
      );
    }
    final current = _items[productId];
    if (current == null) {
      return this;
    }
    final updated = Map<int, CartItem>.of(_items)
      ..[productId] = current.withQuantity(quantity);
    return Cart._(Map.unmodifiable(updated));
  }

  Cart remove(int productId) {
    if (!_items.containsKey(productId)) {
      return this;
    }
    final updated = Map<int, CartItem>.of(_items)..remove(productId);
    return Cart._(Map.unmodifiable(updated));
  }

  Cart clear() => Cart.empty();
}
