import 'package:flutter/material.dart';

import '../../../app_assets.dart';
import '../../../core/theme/ps_colors.dart';
import '../../../core/theme/ps_tokens.dart';

/// How each product in the waterfall is drawn.
enum WaterfallTileStyle {
  /// Bare product cut-outs: the faint backdrop behind the login form.
  plain,

  /// Products on white rounded cards with a soft shadow: the welcome page.
  card,
}

/// A continuously scrolling product wall.
///
/// Each lane renders two copies of the same sequence. Moving by exactly one
/// sequence length means the animation restarts at zero without a visible
/// jump, so the lanes flow forever. Neighbouring lanes move in opposite
/// directions. Respects the system "reduce motion" setting.
class WaterfallProductCarousel extends StatefulWidget {
  const WaterfallProductCarousel({
    super.key,
    this.laneCount,
    this.style = WaterfallTileStyle.plain,
    this.duration = const Duration(seconds: 22),
  });

  /// Number of columns. Null keeps the login layout: four, or three on very
  /// narrow phones.
  final int? laneCount;
  final WaterfallTileStyle style;

  /// Time for one lane to travel its whole sequence once.
  final Duration duration;

  @override
  State<WaterfallProductCarousel> createState() => _WaterfallProductCarouselState();
}

class _WaterfallProductCarouselState extends State<WaterfallProductCarousel> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// Login layout: four lanes.
  static const _fourLanes = <List<int>>[
    [0, 3, 6, 1],
    [4, 7, 2, 9],
    [5, 1, 10, 3],
    [2, 8, 0, 11],
  ];

  /// Welcome layout: three lanes. Leaves out the lotion photo (index 4),
  /// whose baked-in checkerboard background shows on the white cards.
  static const _threeLanes = <List<int>>[
    [0, 3, 6, 9],
    [7, 1, 10, 2],
    [5, 11, 8, 3],
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final card = widget.style == WaterfallTileStyle.card;

    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 360;
          final laneCount = widget.laneCount ?? (compact ? 3 : 4);
          final lanes = laneCount == 3 ? _threeLanes : _fourLanes;
          final gap = card ? PsSpace.sm : (compact ? PsSpace.xs : PsSpace.sm);
          final cardWidth = (constraints.maxWidth - gap * (laneCount - 1)) / laneCount;
          final cardHeight = cardWidth * (card ? 1.22 : 1.18);

          return AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var lane = 0; lane < laneCount; lane++) ...[
                  if (lane > 0) SizedBox(width: gap),
                  Expanded(
                    child: _WaterfallLane(
                      images: lanes[lane % lanes.length],
                      width: cardWidth,
                      height: cardHeight,
                      gap: gap,
                      // Stagger the lanes so the rows never line up.
                      progress: reducedMotion ? 0 : (_controller.value + lane * 0.17) % 1,
                      reverse: lane.isOdd,
                      card: card,
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
    required this.card,
  });

  final List<int> images;
  final double width;
  final double height;
  final double gap;
  final double progress;
  final bool reverse;
  final bool card;

  @override
  Widget build(BuildContext context) {
    // One sequence = every tile plus the gap after it, so the second copy
    // starts exactly where the first one began.
    final sequenceHeight = images.length * (height + gap);
    final offset = reverse ? sequenceHeight * (progress - 1) : sequenceHeight * -progress;
    final tiles = [...images, ...images, ...images];

    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.topCenter,
        maxHeight: double.infinity,
        child: Transform.translate(
          offset: Offset(0, offset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final i in tiles) ...[
                card
                    ? _CardTile(assetPath: AppAssets.loginWaterfall[i], width: width, height: height)
                    : _ProductTile(assetPath: AppAssets.loginWaterfall[i], width: width, height: height),
                SizedBox(height: gap),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.assetPath, required this.width, required this.height});

  final String assetPath;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Padding(
        padding: const EdgeInsets.all(PsSpace.xs),
        child: Image.asset(
          assetPath,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class _CardTile extends StatelessWidget {
  const _CardTile({required this.assetPath, required this.width, required this.height});

  final String assetPath;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(PsSpace.md),
      decoration: BoxDecoration(
        color: PsColors.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 18, offset: Offset(0, 6)),
        ],
      ),
      child: Image.asset(
        assetPath,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }
}
