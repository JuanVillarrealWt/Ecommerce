import 'dart:convert';

import 'package:flutter/material.dart';

class ProductImage extends StatelessWidget {
  const ProductImage({
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.iconSize = 72,
    super.key,
  });

  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fallback = Container(
      width: width,
      height: height,
      color: colors.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        Icons.shopping_bag_outlined,
        size: iconSize,
        color: colors.onSurfaceVariant,
      ),
    );
    final source = imageUrl;
    if (source == null || source.isEmpty) return fallback;

    if (source.startsWith('data:image') && source.contains(',')) {
      try {
        return Image.memory(
          base64Decode(source.substring(source.indexOf(',') + 1)),
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, _, _) => fallback,
        );
      } on FormatException {
        return fallback;
      }
    }

    final uri = Uri.tryParse(source);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return fallback;
    }

    return Image.network(
      source,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          width: width,
          height: height,
          color: colors.surfaceContainerHighest,
          alignment: Alignment.center,
          child: SizedBox(
            width: iconSize > 24 ? 20 : 14,
            height: iconSize > 24 ? 20 : 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colors.primary.withValues(alpha: 0.5),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        debugPrint('ProductImage error loading from $source: $error');
        return fallback;
      },
    );
  }
}
