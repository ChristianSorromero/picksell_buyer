import 'package:flutter/material.dart';

import '../../../core/theme/ps_colors.dart';
import '../../../core/theme/ps_tokens.dart';
import '../../../core/theme/ps_typography.dart';

/// SYS-C12 Loading State.
///
/// Prefer skeletons ([PsSkeleton], [PsSkeletonList]) that match the final
/// layout; use [PsLoadingState] only when the layout is unknown.
class PsLoadingState extends StatelessWidget {
  const PsLoadingState({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: message ?? 'Loading',
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox.square(
              dimension: 32,
              child: CircularProgressIndicator(strokeWidth: 3, color: PsColors.primary),
            ),
            if (message != null) ...[
              const SizedBox(height: PsSpace.md),
              Text(message!, style: PsText.bodyMuted),
            ],
          ],
        ),
      ),
    );
  }
}

/// Pulsing placeholder block. Wrap several in a [PsSkeletonGroup] so they
/// pulse in sync with a single animation.
class PsSkeleton extends StatelessWidget {
  const PsSkeleton({
    super.key,
    this.width,
    required this.height,
    this.radius = PsRadius.sm,
    this.circle = false,
  });

  final double? width;
  final double height;
  final double radius;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final t = _SkeletonPulse.of(context);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Color.lerp(PsColors.surfaceMuted, PsColors.border, t),
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(radius),
      ),
    );
  }
}

/// Drives the pulse for every [PsSkeleton] below it.
class PsSkeletonGroup extends StatefulWidget {
  const PsSkeletonGroup({super.key, required this.child});

  final Widget child;

  @override
  State<PsSkeletonGroup> createState() => _PsSkeletonGroupState();
}

class _PsSkeletonGroupState extends State<PsSkeletonGroup> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, child) => _SkeletonPulse(value: Curves.easeInOut.transform(_c.value), child: child!),
        child: ExcludeSemantics(child: widget.child),
      ),
    );
  }
}

class _SkeletonPulse extends InheritedWidget {
  const _SkeletonPulse({required this.value, required super.child});

  final double value;

  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SkeletonPulse>()?.value ?? 0.5;

  @override
  bool updateShouldNotify(_SkeletonPulse old) => old.value != value;
}

/// Generic card-row skeleton list (thumbnail + two lines), matching the
/// shape of order, cart and notification rows.
class PsSkeletonList extends StatelessWidget {
  const PsSkeletonList({super.key, this.itemCount = 4, this.thumbnail = true});

  final int itemCount;
  final bool thumbnail;

  @override
  Widget build(BuildContext context) {
    return PsSkeletonGroup(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(PsSpace.gutter),
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(height: PsSpace.sm),
        itemBuilder: (_, __) => Container(
          padding: const EdgeInsets.all(PsSpace.md),
          decoration: BoxDecoration(
            color: PsColors.surface,
            borderRadius: PsRadius.card,
            border: Border.all(color: PsColors.border),
          ),
          child: Row(
            children: [
              if (thumbnail) ...[
                const PsSkeleton(width: 64, height: 64, radius: PsRadius.sm),
                const SizedBox(width: PsSpace.md),
              ],
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PsSkeleton(height: 14, width: 160),
                    SizedBox(height: 10),
                    PsSkeleton(height: 12, width: 90),
                    SizedBox(height: 10),
                    PsSkeleton(height: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
