import 'dart:convert';
import 'package:flutter/material.dart';

import '../domain/product.dart';

class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({
    required this.product,
    required this.onAddToCart,
    super.key,
  });

  final Product product;
  final Future<void> Function(Product product, int quantity) onAddToCart;

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  int _quantity = 1;
  bool _isAdding = false;

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final image = product.imageUrl;

    Widget imageWidget = const Icon(Icons.shopping_bag_outlined, size: 90, color: Colors.grey);
    if (image != null && image.startsWith('data:image') && image.contains(',')) {
      try {
        imageWidget = Image.memory(
          base64Decode(image.split(',').last),
          fit: BoxFit.contain,
        );
      } catch (_) {}
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                height: 240,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(16),
                child: Center(child: imageWidget),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              product.name,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '\$${product.price.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: const Color(0xFF246B5A),
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const Divider(height: 32),
            Text(
              'Descripción comercial',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              product.description ?? 'Sin descripción adicional registrada en Odoo.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.black87),
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                Text('Cantidad:', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(width: 16),
                IconButton.outlined(
                  onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                  icon: const Icon(Icons.remove),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('$_quantity', style: Theme.of(context).textTheme.titleLarge),
                ),
                IconButton.outlined(
                  onPressed: () => setState(() => _quantity++),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF246B5A)),
                onPressed: _isAdding
                    ? null
                    : () async {
                        setState(() => _isAdding = true);
                        await widget.onAddToCart(product, _quantity);
                        if (mounted) {
                          setState(() => _isAdding = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Se agregaron $_quantity unidad(es) de ${product.name} al carrito.'),
                              backgroundColor: const Color(0xFF246B5A),
                            ),
                          );
                        }
                      },
                icon: const Icon(Icons.add_shopping_cart),
                label: Text(
                  _isAdding ? 'Agregando...' : 'Agregar al carrito (\$${(product.price * _quantity).toStringAsFixed(2)})',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
