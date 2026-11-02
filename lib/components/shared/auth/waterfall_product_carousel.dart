import 'package:flutter/material.dart';

import '../../../app_assets.dart';
import '../../../core/theme/ps_tokens.dart';

/// A subtle, continuously scrolling product wall for the login backdrop.
///
/// Each lane renders two copies of the same sequence. Moving by exactly one
/// sequence length means the animation can restart at zero without a visible
/// jump.
class WaterfallProductCarousel extends StatefulWidget {
  const WaterfallProductCarousel({super.key});

  @override
  State<WaterfallProductCarousel> createState() =>
      _WaterfallProductCarouselState();
}

class _WaterfallProductCarouselState extends State<WaterfallProductCarousel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const _lanes = <List<int>>[
    [0, 3, 6, 1],
    [4, 7, 2, 9],
    [5, 1, 10, 3],
    [2, 8, 0, 11],
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 22),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);

    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 360;
          final laneCount = compact ? 3 : _lanes.length;
          final gap = compact ? PsSpace.xs : PsSpace.sm;
          final cardWidth =
              (constraints.maxWidth - gap * (laneCount - 1)) / laneCount;
          final cardHeight = cardWidth * 1.18;

          return AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var lane = 0; lane < laneCount; lane++) ...[
                  if (lane > 0) SizedBox(width: gap),
                  Expanded(
                    child: _WaterfallLane(
                      images: _lanes[lane],
                      width: cardWidth,
                      height: cardHeight,
                      gap: gap,
                      progress: reducedMotion ? 0 : _controller.value,
                      reverse: lane.isOdd,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _WaterfallLane extends StatelessWidget {
  const _WaterfallLane({
    required this.images,
    required this.width,
    required this.height,
    required this.gap,
    required this.progress,
    required this.reverse,
  });

  final List<int> images;
  final double width;
  final double height;
  final double gap;
  final double progress;
  final bool reverse;

  @override
  Widget build(BuildContext context) {
    final sequenceHeight = images.length * height + (images.length - 1) * gap;
    final offset = reverse
        ? sequenceHeight * (progress - 1)
        : sequenceHeight * -progress;
    final tiles = [...images, ...images];

    return ClipRect(
      child: Transform.translate(
        offset: Offset(0, offset),
        child: Column(
          children: [
            for (var i = 0; i < tiles.length; i++) ...[
              _ProductTile(
                assetPath: AppAssets.loginWaterfall[tiles[i]],
                width: width,
                height: height,
              ),
              if (i < tiles.length - 1) SizedBox(height: gap),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.assetPath,
    required this.width,
    required this.height,
  });

  final String assetPath;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(PsSpace.xs),
      child: Image.asset(
        assetPath,
        width: width,
        height: height,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }
}
