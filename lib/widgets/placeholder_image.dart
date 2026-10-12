import 'package:flutter/material.dart';

import '../app_colors.dart';

/// Shows [assetPath] when the file exists, otherwise a neutral placeholder.
///
/// This makes swapping in real artwork effortless: add the file at the asset
/// path and the placeholder disappears.
class PlaceholderImage extends StatelessWidget {
  const PlaceholderImage({
    super.key,
    this.assetPath,
    this.icon = Icons.image_outlined,
    this.label,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.backgroundColor = AppColors.primaryLight,
    this.iconColor = AppColors.primary,
    this.iconSize = 56,
    this.borderRadius = BorderRadius.zero,
  });

  final String? assetPath;
  final IconData icon;
  final String? label;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Color backgroundColor;
  final Color iconColor;
  final double iconSize;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: iconSize, color: iconColor.withAlpha(150)),
              if (label != null) ...[
                const SizedBox(height: 6),
                Text(
                  label!,
                  style: TextStyle(
                    fontSize: 12,
                    color: iconColor.withAlpha(150),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (assetPath == null) return placeholder;

    return ClipRRect(
      borderRadius: borderRadius,
      child: Image.asset(
        assetPath!,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => placeholder,
      ),
    );
  }
}
