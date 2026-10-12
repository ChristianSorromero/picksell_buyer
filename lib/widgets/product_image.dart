import 'package:flutter/material.dart';

import '../app_colors.dart';

/// Product picture with placeholder fallback.
///
/// [url] is the image uploaded by the seller (from the website/back-end).
/// When it is null/empty, still loading, or fails to load, a tinted
/// placeholder is shown instead — so swapping in real images needs no changes.
class ProductImage extends StatelessWidget {
  const ProductImage({
    super.key,
    this.url,
    this.seed = 0,
    this.fit = BoxFit.cover,
    this.borderRadius = BorderRadius.zero,
    this.iconSize = 40,
  });

  final String? url;

  /// Picks the placeholder tint so neighbouring cards look different.
  final int seed;
  final BoxFit fit;
  final BorderRadius borderRadius;
  final double iconSize;

  static const List<Color> _tints = [
    AppColors.tileYellow,
    AppColors.tileGrey,
    AppColors.tileMint,
    AppColors.tileRose,
    AppColors.tileCream,
    AppColors.tileLight,
  ];

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _tints[seed.abs() % _tints.length],
        borderRadius: borderRadius,
      ),
      child: Icon(Icons.image_outlined, size: iconSize, color: Colors.black26),
    );

    final imageUrl = url;
    if (imageUrl == null || imageUrl.isEmpty) return placeholder;

    return ClipRRect(
      borderRadius: borderRadius,
      child: Image.network(
        imageUrl,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        headers: const {'ngrok-skip-browser-warning': 'true'},
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : placeholder,
        errorBuilder: (_, __, ___) => placeholder,
      ),
    );
  }
}
