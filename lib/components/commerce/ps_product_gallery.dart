import 'package:flutter/material.dart';

import '../../core/theme/ps_colors.dart';
import '../../core/theme/ps_tokens.dart';
import '../../core/theme/ps_typography.dart';
import '../shared/ps_motion.dart';
import 'ps_product_image.dart';

/// COM-C02 Product Image Gallery — swipeable images with a "1/6" counter
/// and a thumbnail strip when there is more than one image. Photos are shown
/// whole (never cropped); tapping one opens [PsImageViewer].
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

  /// Full screen at [start]; closing lands the gallery on the photo the
  /// buyer ended on (the page's scroll position is untouched).
  Future<void> _openViewer(int start) async {
    final end = await PsImageViewer.show(context, images: widget.images, initialIndex: start);
    if (!mounted || end == null || end == _index || !_controller.hasClients) return;
    _controller.jumpToPage(end);
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
                itemBuilder: (_, i) => images[i] == null
                    ? PsProductImage(url: null, iconSize: 56)
                    : Semantics(
                        button: true,
                        label: 'Photo ${i + 1} of ${images.length}. Open full screen',
                        child: GestureDetector(
                          onTap: () => _openViewer(i),
                          child: ColoredBox(
                            color: PsColors.surfaceMuted,
                            // Portrait, landscape or square: the whole photo, letterboxed.
                            child: PsProductImage(url: images[i], fit: BoxFit.contain, iconSize: 56),
                          ),
                        ),
                      ),
              ),
              if (images.length > 1)
                Positioned(
                  right: PsSpace.md,
                  bottom: PsSpace.md,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(PsRadius.pill),
                    ),
                    child: PsValueSwap(
                      value: _index,
                      child: Text(
                        '${_index + 1}/${images.length}',
                        style: PsText.caption.copyWith(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              // Position dots: the active one stretches into a short bar.
              if (images.length > 1 && images.length <= 8)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: PsSpace.md + 6,
                  child: ExcludeSemantics(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < images.length; i++)
                          AnimatedContainer(
                            duration: PsMotion.duration(context, PsMotion.small),
                            curve: PsMotion.change,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: i == _index ? 18 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: i == _index ? Colors.white : Colors.white.withAlpha(140),
                              borderRadius: BorderRadius.circular(3),
                              boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 3)],
                            ),
                          ),
                      ],
                    ),
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
                onTap: () => PsMotion.reduced(context)
                    ? _controller.jumpToPage(i)
                    : _controller.animateToPage(i, duration: PsMotion.content, curve: PsMotion.change),
                child: AnimatedContainer(
                  duration: PsMotion.duration(context, PsMotion.small),
                  width: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: i == _index ? PsColors.primary : PsColors.border,
                      width: i == _index ? 2 : 1,
                    ),
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

/// Full-screen photo viewer: swipe between photos, pinch or double-tap to
/// zoom, drag to pan, "2/5" counter and a close button. Pops with the index
/// of the photo last shown.
class PsImageViewer extends StatefulWidget {
  const PsImageViewer({super.key, required this.images, this.initialIndex = 0});

  final List<String> images;
  final int initialIndex;

  static Future<int?> show(BuildContext context, {required List<String> images, int initialIndex = 0}) {
    if (images.isEmpty) return Future.value(null);
    return Navigator.of(context).push<int>(PageRouteBuilder(
      opaque: true,
      barrierColor: Colors.black,
      transitionDuration: PsMotion.duration(context, PsMotion.normal),
      pageBuilder: (_, __, ___) => PsImageViewer(images: images, initialIndex: initialIndex.clamp(0, images.length - 1)),
      transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
    ));
  }

  @override
  State<PsImageViewer> createState() => _PsImageViewerState();
}

class _PsImageViewerState extends State<PsImageViewer> {
  late final _pages = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;
  final _zoom = TransformationController();
  Offset _doubleTapAt = Offset.zero;

  /// While zoomed in, a drag pans the photo instead of turning the page.
  bool _zoomed = false;

  @override
  void dispose() {
    _pages.dispose();
    _zoom.dispose();
    super.dispose();
  }

  void _syncZoomed() {
    final z = _zoom.value.getMaxScaleOnAxis() > 1.01;
    if (z != _zoomed) setState(() => _zoomed = z);
  }

  void _toggleZoom() {
    if (_zoomed) {
      _zoom.value = Matrix4.identity();
    } else {
      const scale = 2.5;
      final p = _doubleTapAt;
      _zoom.value = Matrix4.identity()
        ..translateByDouble(-p.dx * (scale - 1), -p.dy * (scale - 1), 0, 1)
        ..scaleByDouble(scale, scale, 1, 1);
    }
    _syncZoomed();
  }

  void _close() => Navigator.of(context).pop(_index);

  @override
  Widget build(BuildContext context) {
    final count = widget.images.length;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            PageView.builder(
              controller: _pages,
              itemCount: count,
              physics: _zoomed ? const NeverScrollableScrollPhysics() : const PageScrollPhysics(),
              onPageChanged: (i) {
                // A new photo always starts un-zoomed.
                _zoom.value = Matrix4.identity();
                setState(() {
                  _index = i;
                  _zoomed = false;
                });
              },
              itemBuilder: (_, i) => GestureDetector(
                onDoubleTapDown: (d) => _doubleTapAt = d.localPosition,
                onDoubleTap: _toggleZoom,
                child: InteractiveViewer(
                  transformationController: i == _index ? _zoom : null,
                  minScale: 1,
                  maxScale: 5,
                  onInteractionEnd: (_) => _syncZoomed(),
                  child: SizedBox.expand(
                    child: PsProductImage(
                      url: widget.images[i],
                      fit: BoxFit.contain,
                      fullResolution: true,
                      iconSize: 64,
                      semanticLabel: 'Photo ${i + 1} of $count',
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: PsSpace.xs, vertical: PsSpace.xs),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Close',
                      onPressed: _close,
                      style: IconButton.styleFrom(backgroundColor: Colors.black54, foregroundColor: Colors.white),
                      icon: const Icon(Icons.close_rounded),
                    ),
                    const Spacer(),
                    if (count > 1)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(PsRadius.pill)),
                        child: Text('${_index + 1}/$count', style: PsText.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                    const SizedBox(width: PsSpace.xs),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
