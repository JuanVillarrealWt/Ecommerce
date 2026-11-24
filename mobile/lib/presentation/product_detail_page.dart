import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/product.dart';
import '../application/customer_features_repository.dart';
import 'product_image.dart';

class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({
    required this.product,
    this.maxAvailableQuantity,
    required this.onAddToCart,
    this.customerFeaturesRepository,
    required this.isFavorite,
    required this.onToggleFavorite,
    super.key,
  });

  final Product product;
  final int? maxAvailableQuantity;
  final Future<void> Function(Product product, int quantity) onAddToCart;
  final CustomerFeaturesRepository? customerFeaturesRepository;
  final bool isFavorite;
  final Future<bool> Function() onToggleFavorite;

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  int _quantity = 1;
  bool _isAdding = false;
  late bool _isFavorite;
  late TextEditingController _qtyController;
  late Future<List<Map<String, dynamic>>> _reviewsFuture;
  late Future<Map<String, dynamic>?> _ownReviewFuture;
  late Future<int?> _reviewOrderFuture;
  String? _stockError;
  int get _maxQuantity => widget.maxAvailableQuantity ?? widget.product.stock;

  @override
  void initState() {
    super.initState();
    _qtyController = TextEditingController(text: '$_quantity');
    _isFavorite = widget.isFavorite;
    _reviewsFuture =
        widget.customerFeaturesRepository?.productReviews(widget.product.id) ??
        Future.value(const []);
    _ownReviewFuture = _loadOwnReview();
    _reviewOrderFuture = _loadReviewOrderId();
  }

  Future<Map<String, dynamic>?> _loadOwnReview() async {
    final repository = widget.customerFeaturesRepository;
    if (repository == null) return null;
    try {
      final data = await repository.load();
      final reviews = (data['reviews'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item));
      for (final review in reviews) {
        if (review['productId'] == widget.product.id) return review;
      }
    } catch (_) {}
    return null;
  }

  Future<int?> _loadReviewOrderId() async {
    final repository = widget.customerFeaturesRepository;
    if (repository == null) return null;
    try {
      return await repository.reviewOrderId(widget.product.id);
    } catch (_) {
      return null;
    }
  }

  Future<void> _editOwnReview(Map<String, dynamic> review) async {
    final repository = widget.customerFeaturesRepository;
    if (repository == null) return;
    final comment = TextEditingController(text: '${review['comment'] ?? ''}');
    var rating = (review['rating'] as num?)?.toInt() ?? 5;
    var saving = false;
    var isDirty = false;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Editar mi reseña'),
            scrollable: true,
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var value = 1; value <= 5; value++)
                        IconButton(
                          constraints: const BoxConstraints.tightFor(
                            width: 36,
                            height: 36,
                          ),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          onPressed: saving
                              ? null
                              : () => setDialogState(() {
                                  rating = value;
                                  isDirty = true;
                                }),
                          icon: Icon(
                            value <= rating ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                          ),
                        ),
                    ],
                  ),
                  TextField(
                    controller: comment,
                    maxLength: 1000,
                    maxLines: 4,
                    onChanged: (_) => setDialogState(() => isDirty = true),
                    decoration: const InputDecoration(
                      labelText: 'Comentario',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (isDirty) {
                          final discard = await showDialog<bool>(
                            context: dialogContext,
                            barrierDismissible: false,
                            builder: (confirmContext) => AlertDialog(
                              title: const Text('¿Descartar cambios?'),
                              content: const Text(
                                'Tienes cambios en tu reseña. ¿Quieres salir sin guardarlos?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(confirmContext, false),
                                  child: const Text('Seguir editando'),
                                ),
                                FilledButton.tonal(
                                  onPressed: () =>
                                      Navigator.pop(confirmContext, true),
                                  child: const Text('Descartar'),
                                ),
                              ],
                            ),
                          );
                          if (discard != true || !dialogContext.mounted) return;
                        }
                        Navigator.pop(dialogContext, false);
                      },
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        final orderId = (review['orderId'] as num?)?.toInt();
                        if (orderId == null) return;
                        setDialogState(() => saving = true);
                        try {
                          await repository.submitReview(
                            productId: widget.product.id,
                            orderId: orderId,
                            rating: rating,
                            comment: comment.text.trim(),
                          );
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext, true);
                          }
                        } catch (_) {
                          if (dialogContext.mounted) {
                            setDialogState(() => saving = false);
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'No se pudo actualizar la reseña. Intenta de nuevo.',
                                ),
                              ),
                            );
                          }
                        }
                      },
                child: saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Guardar'),
              ),
            ],
          ),
        ),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => comment.dispose());
    if (result == true && mounted) {
      setState(() {
        _reviewsFuture = repository.productReviews(widget.product.id);
        _ownReviewFuture = _loadOwnReview();
      });
    }
  }

  Future<void> _deleteOwnReview() async {
    final repository = widget.customerFeaturesRepository;
    if (repository == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar mi reseña'),
        content: const Text('¿Quieres eliminar tu calificación y comentario?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await repository.deleteReview(widget.product.id);
      if (!mounted) return;
      setState(() {
        _reviewsFuture = repository.productReviews(widget.product.id);
        _ownReviewFuture = Future.value(null);
        _reviewOrderFuture = _loadReviewOrderId();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tu reseña se eliminó.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo eliminar la reseña.')),
      );
    }
  }

  Future<void> _addProductReview(int orderId) async {
    final repository = widget.customerFeaturesRepository;
    if (repository == null) return;
    final comment = TextEditingController();
    var rating = 5;
    var sending = false;
    var dirty = false;

    Future<void> closeDialog(BuildContext dialogContext) async {
      if (sending) return;
      if (dirty) {
        final discard = await showDialog<bool>(
          context: dialogContext,
          barrierDismissible: false,
          builder: (confirmContext) => AlertDialog(
            title: const Text('¿Descartar reseña?'),
            content: const Text('Tu comentario aún no se ha guardado.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(confirmContext, false),
                child: const Text('Seguir escribiendo'),
              ),
              FilledButton.tonal(
                onPressed: () => Navigator.pop(confirmContext, true),
                child: const Text('Descartar'),
              ),
            ],
          ),
        );
        if (discard != true || !dialogContext.mounted) return;
      }
      Navigator.pop(dialogContext, false);
    }

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) closeDialog(dialogContext);
        },
        child: StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const Text('Califica este producto'),
            scrollable: true,
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var value = 1; value <= 5; value++)
                        IconButton(
                          constraints: const BoxConstraints.tightFor(
                            width: 36,
                            height: 36,
                          ),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          onPressed: sending
                              ? null
                              : () => setDialogState(() {
                                  rating = value;
                                  dirty = true;
                                }),
                          icon: Icon(
                            value <= rating ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                          ),
                        ),
                    ],
                  ),
                  const Text(
                    'Puedes enviar solo las estrellas; el comentario es opcional.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: comment,
                    maxLength: 1000,
                    maxLines: 3,
                    onChanged: (_) => setDialogState(() => dirty = true),
                    decoration: const InputDecoration(
                      labelText: 'Comentario (opcional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: sending ? null : () => closeDialog(dialogContext),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: sending
                    ? null
                    : () async {
                        setDialogState(() => sending = true);
                        try {
                          await repository.submitReview(
                            productId: widget.product.id,
                            orderId: orderId,
                            rating: rating,
                            comment: comment.text.trim(),
                          );
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext, true);
                          }
                        } catch (_) {
                          if (dialogContext.mounted) {
                            setDialogState(() => sending = false);
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'No se pudo guardar la reseña. Intenta de nuevo.',
                                ),
                              ),
                            );
                          }
                        }
                      },
                child: sending
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Enviar'),
              ),
            ],
          ),
        ),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => comment.dispose());
    if (saved == true && mounted) {
      setState(() {
        _reviewsFuture = repository.productReviews(widget.product.id);
        _ownReviewFuture = _loadOwnReview();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gracias por compartir tu opinión.')),
      );
    }
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
      _stockError = 'Stock insuficiente: solo hay $_maxQuantity disponibles.';
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
                              Icon(
                                Icons.zoom_in,
                                color: Colors.white,
                                size: 16,
                              ),
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
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _reviewsFuture,
              builder: (context, snapshot) {
                final reviews = snapshot.data ?? const [];
                final average = reviews.isEmpty
                    ? 0.0
                    : reviews
                              .map((item) => item['rating'] as int? ?? 0)
                              .fold<int>(0, (sum, rating) => sum + rating) /
                          reviews.length;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Calificación de clientes',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            for (var star = 1; star <= 5; star++)
                              Icon(
                                star <= average
                                    ? Icons.star
                                    : (star - 0.5 <= average
                                          ? Icons.star_half
                                          : Icons.star_border),
                                size: 20,
                                color: Colors.amber,
                              ),
                            const SizedBox(width: 8),
                            Text(
                              '${average.toStringAsFixed(1)} · ${reviews.length} ${reviews.length == 1 ? 'reseña' : 'reseñas'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        if (snapshot.connectionState == ConnectionState.waiting)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: LinearProgressIndicator(),
                          )
                        else if (reviews.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text('Aún no hay calificaciones.'),
                          )
                        else ...[
                          const Divider(height: 20),
                          for (final review in reviews.take(5))
                            _buildReviewTile(review),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
            FutureBuilder<Map<String, dynamic>?>(
              future: _ownReviewFuture,
              builder: (context, ownSnapshot) {
                final ownReview = ownSnapshot.data;
                if (ownReview != null) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    child: Card(
                      color: Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.35),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Tu reseña: ${ownReview['rating']}/5 · "${ownReview['comment'] ?? ''}"',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => _editOwnReview(ownReview),
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              label: const Text('Editar'),
                            ),
                            IconButton(
                              tooltip: 'Eliminar reseña',
                              onPressed: _deleteOwnReview,
                              icon: const Icon(Icons.delete_outline, size: 18),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                return FutureBuilder<int?>(
                  future: _reviewOrderFuture,
                  builder: (context, orderSnapshot) {
                    final orderId = orderSnapshot.data;
                    if (orderId == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.tonalIcon(
                          onPressed: () => _addProductReview(orderId),
                          icon: const Icon(Icons.rate_review_outlined),
                          label: const Text('Calificar este producto'),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
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
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final saved = await widget.onToggleFavorite();
                    if (saved && mounted)
                      setState(() => _isFavorite = !_isFavorite);
                  },
                  icon: Icon(
                    _isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: _isFavorite ? Colors.pink : null,
                  ),
                  label: Text(_isFavorite ? 'En favoritos' : 'Favorito'),
                ),
              ],
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
                        if (!RegExp(r'^\d+$').hasMatch(text) ||
                            text.startsWith('0') ||
                            parsed == null ||
                            parsed > _maxQuantity)
                          return oldValue;
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

  Widget _buildReviewTile(Map<String, dynamic> review) {
    final customerName = '${review['customerName'] ?? ''}'.trim();
    final comment = '${review['comment'] ?? ''}'.trim();
    final details = [
      if (customerName.isNotEmpty) customerName,
      if (comment.isNotEmpty) comment,
    ].join('\n');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.star, color: Colors.amber),
      title: Text('${review['rating']}/5'),
      subtitle: Text(details.isEmpty ? 'Calificación de un cliente' : details),
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
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 28,
                    ),
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
