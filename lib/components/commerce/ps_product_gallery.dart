import 'package:flutter/material.dart';

import '../../core/theme/ps_colors.dart';
import '../../core/theme/ps_tokens.dart';
import '../../core/theme/ps_typography.dart';
import 'ps_product_image.dart';

/// COM-C02 Product Image Gallery — swipeable images with a "1/6" counter
/// and a thumbnail strip when there is more than one image.
class PsProductGallery extends StatefulWidget {
  const PsProductGallery({super.key, required this.images, this.overlay = const []});

  final List<String> images;

  /// Widgets stacked on top (back button, wishlist heart).
  final List<Widget> overlay;

  @override
  State<PsProductGallery> createState() => _PsProductGalleryState();
}

class _PsProductGalleryState extends State<PsProductGallery> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.images.isEmpty ? <String?>[null] : widget.images;
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: Stack(
            children: [
              PageView.builder(
                controller: _controller,
                itemCount: images.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) => PsProductImage(url: images[i], iconSize: 56),
              ),
              if (images.length > 1)
                Positioned(
                  right: PsSpace.md,
                  bottom: PsSpace.md,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(PsRadius.pill)),
                    child: Text('${_index + 1}/${images.length}', style: PsText.caption.copyWith(color: Colors.white)),
                  ),
                ),
              ...widget.overlay,
            ],
          ),
        ),
        if (images.length > 1)
          SizedBox(
            height: 76,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(PsSpace.gutter, PsSpace.sm, PsSpace.gutter, 0),
              itemCount: images.length,
              separatorBuilder: (_, __) => const SizedBox(width: PsSpace.xs),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => _controller.animateToPage(i, duration: PsMotion.normal, curve: PsMotion.curve),
                child: Container(
                  width: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: i == _index ? PsColors.primary : PsColors.border, width: i == _index ? 2 : 1),
                  ),
                  child: PsProductImage(url: images[i], borderRadius: BorderRadius.circular(6), iconSize: 18),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
