import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
    this.fullResolution = false,
    this.placeholder,
  });

  final String? url;
  final BoxFit fit;
  final BorderRadius borderRadius;
  final double iconSize;
  final String? semanticLabel;

  /// Decode at the photo's own size (full-screen viewer, where the buyer
  /// zooms in) instead of the size it is drawn.
  final bool fullResolution;

  /// Shown while loading, when missing or when the URL fails (default: a
  /// neutral photo icon). A store logo uses the store's initials.
  final Widget? placeholder;

  @override
  Widget build(BuildContext context) {
    final placeholder = this.placeholder ?? Container(
      color: PsColors.surfaceMuted,
      alignment: Alignment.center,
      child: Icon(Icons.image_outlined, size: iconSize, color: PsColors.textHint),
    );

    final src = url;
    if (src == null || src.isEmpty) {
      return ClipRRect(borderRadius: borderRadius, child: SizedBox.expand(child: placeholder));
    }

    // Web: /storage files carry no CORS headers, so a fetch fails; an <img>
    // element displays them fine, and the browser does its own caching.
    if (kIsWeb) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: SizedBox.expand(
          child: Image.network(
            src,
            fit: fit,
            width: double.infinity,
            height: double.infinity,
            semanticLabel: semanticLabel,
            webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
            loadingBuilder: (_, child, progress) => progress == null ? child : placeholder,
            errorBuilder: (_, __, ___) => placeholder,
          ),
        ),
      );
    }

    // Phone: photos are kept on the device after the first download, so going
    // back to a screen shows them at once, and each one is decoded at the size
    // it is drawn (a card thumbnail doesn't hold a full-size photo in memory).
    return ClipRRect(
      borderRadius: borderRadius,
      child: LayoutBuilder(
        builder: (context, box) {
          final dpr = MediaQuery.devicePixelRatioOf(context);
          final w = !fullResolution && box.maxWidth.isFinite ? (box.maxWidth * dpr).round() : null;
          return Semantics(
            image: true,
            label: semanticLabel,
            child: CachedNetworkImage(
              imageUrl: src,
              fit: fit,
              width: double.infinity,
              height: double.infinity,
              memCacheWidth: w,
              httpHeaders: const {'ngrok-skip-browser-warning': 'true'},
              fadeInDuration: const Duration(milliseconds: 180),
              fadeOutDuration: Duration.zero,
              placeholder: (_, __) => placeholder,
              errorWidget: (_, __, ___) => placeholder,
            ),
          );
        },
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
    final radius = BorderRadius.circular(size >= 60 ? 16 : 12);
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(color: PsColors.neutralSoft, borderRadius: radius),
        child: PsProductImage(url: url, borderRadius: radius, iconSize: size * 0.35),
      ),
    );
  }
}
