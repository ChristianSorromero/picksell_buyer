import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/theme/ps_colors.dart';

/// Seller-uploaded product photo with a neutral placeholder while loading,
/// when missing, or when the URL fails.
class PsProductImage extends StatelessWidget {
  const PsProductImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.borderRadius = BorderRadius.zero,
    this.iconSize = 32,
    this.semanticLabel,
  });

  final String? url;
  final BoxFit fit;
  final BorderRadius borderRadius;
  final double iconSize;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: PsColors.surfaceMuted,
      alignment: Alignment.center,
      child: Icon(Icons.image_outlined, size: iconSize, color: PsColors.textHint),
    );

    final src = url;
    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox.expand(
        child: src == null || src.isEmpty
            ? placeholder
            : Image.network(
                src,
                fit: fit,
                width: double.infinity,
                height: double.infinity,
                semanticLabel: semanticLabel,
                // Web: /storage files carry no CORS headers, so a fetch (and
                // the custom header's preflight) fails; an <img> element
                // displays them fine. Mobile keeps the ngrok header.
                headers: kIsWeb ? null : const {'ngrok-skip-browser-warning': 'true'},
                webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                loadingBuilder: (_, child, progress) => progress == null ? child : placeholder,
                errorBuilder: (_, __, ___) => placeholder,
              ),
      ),
    );
  }
}

/// Fixed-size square thumbnail (cart lines, order rows).
class PsThumbnail extends StatelessWidget {
  const PsThumbnail({super.key, required this.url, this.size = 64});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: PsProductImage(url: url, borderRadius: BorderRadius.circular(8), iconSize: size * 0.35),
    );
  }
}
