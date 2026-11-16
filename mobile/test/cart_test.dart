import 'package:flutter_test/flutter_test.dart';
import 'package:ecommerce_mobile/domain/cart.dart';
import 'package:ecommerce_mobile/domain/product.dart';

void main() {
  group('PA-01: Pruebas unitarias de carrito móvil', () {
    const productA = Product(
      id: 7,
      name: 'PROD-TEST-001',
      price: 10.0,
      description: 'Producto 1',
    );

    const productB = Product(
      id: 8,
      name: 'PROD-TEST-002',
      price: 15.0,
      description: 'Producto 2',
    );

    test('Agregar producto nuevo al carrito incrementa items y calcula subtotal', () {
      final cart = Cart.empty().add(productA, quantity: 2);

      expect(cart.items.length, 1);
      expect(cart.items.first.product.id, 7);
      expect(cart.items.first.quantity, 2);
      expect(cart.subtotal, 20.0);
    });

    test('Agregar producto existente acumula la cantidad correctamente', () {
      final cart = Cart.empty()
          .add(productA, quantity: 1)
          .add(productA, quantity: 3);

      expect(cart.items.length, 1);
      expect(cart.items.first.quantity, 4);
      expect(cart.subtotal, 40.0);
    });

    test('Rechazar cantidades no positivas (cero o negativas) al agregar', () {
      final cart = Cart.empty();

      expect(() => cart.add(productA, quantity: 0), throwsArgumentError);
      expect(() => cart.add(productA, quantity: -2), throwsArgumentError);
    });

    test('Modificar cantidad de un artículo existente', () {
      final cart = Cart.empty()
          .add(productA, quantity: 2)
          .setQuantity(productA.id, 5);

      expect(cart.items.first.quantity, 5);
      expect(cart.subtotal, 50.0);
    });

    test('Rechazar cantidades no positivas al modificar cantidad', () {
      final cart = Cart.empty().add(productA, quantity: 2);

      expect(() => cart.setQuantity(productA.id, 0), throwsArgumentError);
      expect(() => cart.setQuantity(productA.id, -1), throwsArgumentError);
    });

    test('Eliminar un artículo retira el producto del carrito y actualiza subtotal', () {
      final cart = Cart.empty()
          .add(productA, quantity: 1)
          .add(productB, quantity: 2) // Subtotal: 10 + 30 = 40
          .remove(productA.id);

      expect(cart.items.length, 1);
      expect(cart.items.first.product.id, 8);
      expect(cart.subtotal, 30.0);
    });

    test('Vaciar el carrito restablece la lista de artículos y subtotal a cero', () {
      final cart = Cart.empty()
          .add(productA, quantity: 1)
          .add(productB, quantity: 1)
          .clear();

      expect(cart.isEmpty, isTrue);
      expect(cart.items, isEmpty);
      expect(cart.subtotal, 0.0);
    });
  });
}
