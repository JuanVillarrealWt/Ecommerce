import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/product.dart';
import 'product_image.dart';

class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({
    required this.product,
    this.maxAvailableQuantity,
    required this.onAddToCart,
    super.key,
  });

  final Product product;
  final int? maxAvailableQuantity;
  final Future<void> Function(Product product, int quantity) onAddToCart;

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  int _quantity = 1;
  bool _isAdding = false;
  late TextEditingController _qtyController;
  String? _stockError;
  int get _maxQuantity => widget.maxAvailableQuantity ?? widget.product.stock;

  @override
  void initState() {
    super.initState();
    _qtyController = TextEditingController(text: '$_quantity');
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  void _updateQuantity(int newQty) {
    setState(() {
      _quantity = newQty;
      _qtyController.text = '$newQty';
      _validateStock(newQty);
    });
  }

  void _validateStock(int qty) {
    if (!widget.product.stockTracked) {
      _stockError =
          'El inventario de este producto aún no está configurado en Odoo.';
    } else if (qty > _maxQuantity) {
      _stockError =
          'Stock insuficiente: solo hay $_maxQuantity disponibles.';
    } else if (qty <= 0) {
      _stockError = 'La cantidad debe ser mayor a 0.';
    } else {
      _stockError = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final colors = Theme.of(context).colorScheme;
    final image = product.imageUrl;

    final hasStock = product.stockTracked && product.stock > 0;
    final isValidQty =
        _stockError == null && _quantity > 0 && _quantity <= _maxQuantity;

    return Scaffold(
      appBar: AppBar(
        title: Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: image != null && image.isNotEmpty
                  ? () => _showFullImageDialog(context, image, product.name)
                  : null,
              child: Container(
                height: 260,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ProductImage(
                      imageUrl: image,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      iconSize: 90,
                    ),
                    if (image != null && image.isNotEmpty)
                      Positioned(
                        right: 12,
                        bottom: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.zoom_in, color: Colors.white, size: 16),
                              SizedBox(width: 4),
                              Text(
                                'Ver completa',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              product.name,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '\$${product.price.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // Indicador de Stock
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: hasStock
                        ? colors.tertiaryContainer
                        : colors.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: hasStock ? colors.tertiary : colors.error,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        hasStock
                            ? Icons.inventory_2_outlined
                            : Icons.remove_shopping_cart,
                        size: 16,
                        color: hasStock
                            ? colors.onTertiaryContainer
                            : colors.onErrorContainer,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        !product.stockTracked
                            ? 'Inventario sin configurar'
                            : hasStock
                            ? 'Stock: ${product.stock} uds.'
                            : 'Agotado',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: hasStock
                              ? colors.onTertiaryContainer
                              : colors.onErrorContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            Text(
              'Descripción comercial',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              product.description ??
                  'Sin descripción adicional registrada en Odoo.',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: colors.onSurface),
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                Text(
                  'Cantidad:',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(width: 16),
                IconButton.outlined(
                  onPressed: _quantity > 1
                      ? () => _updateQuantity(_quantity - 1)
                      : null,
                  icon: const Icon(Icons.remove),
                ),
                const SizedBox(width: 8),
                // Campo numérico editable para escribir directamente (ej. 30)
                SizedBox(
                  width: 70,
                  height: 48,
                  child: TextField(
                    controller: _qtyController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      TextInputFormatter.withFunction((oldValue, newValue) {
                        final text = newValue.text;
                        if (text.isEmpty) return newValue;
                        final parsed = int.tryParse(text);
                        if (!RegExp(r'^\d+$').hasMatch(text) || text.startsWith('0') || parsed == null || parsed > _maxQuantity) return oldValue;
                        return newValue;
                      }),
                    ],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: _stockError != null
                              ? Colors.red
                              : colors.primary,
                          width: 2,
                        ),
                      ),
                    ),
                    onChanged: (val) {
                      final parsed = int.tryParse(val) ?? 0;
                      setState(() {
                        _quantity = parsed;
                        _validateStock(parsed);
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  onPressed: _quantity < _maxQuantity
                      ? () => _updateQuantity(_quantity + 1)
                      : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            // Advertencia de stock si supera lo disponible
            if (_stockError != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.red,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _stockError!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: colors.primary),
                onPressed: (!hasStock || !isValidQty || _isAdding)
                    ? null
                    : () async {
                        setState(() => _isAdding = true);
                        await widget.onAddToCart(product, _quantity);
                        if (mounted) {
                          setState(() => _isAdding = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Se agregaron $_quantity unidad(es) de ${product.name} al carrito.',
                              ),
                              backgroundColor: colors.primary,
                            ),
                          );
                        }
                      },
                icon: const Icon(Icons.add_shopping_cart),
                label: Text(
                  _isAdding
                      ? 'Agregando...'
                      : !product.stockTracked
                      ? 'Inventario sin configurar'
                      : !hasStock
                      ? 'Agotado en Odoo'
                      : !isValidQty
                      ? 'Stock no disponible'
                      : 'Agregar al carrito (\$${(product.price * _quantity).toStringAsFixed(2)})',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullImageDialog(
    BuildContext context,
    String imageUrl,
    String productName,
  ) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) {
        final screenSize = MediaQuery.of(ctx).size;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: SizedBox(
            width: screenSize.width - 32,
            height: screenSize.height * 0.75,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(),
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ProductImage(
                          imageUrl: imageUrl,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.contain,
                          iconSize: 90,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 12,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      productName,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
