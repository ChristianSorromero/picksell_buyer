import 'package:flutter/material.dart';

import '../../core/status/order_status.dart';
import '../../core/theme/ps_colors.dart';
import '../../core/theme/ps_tokens.dart';
import '../../core/theme/ps_typography.dart';

enum ThreadStepState { done, current, upcoming }

/// One node on a [PsPickThread]. Build these from real backend tracking
/// events; never fabricate timestamps for upcoming steps.
class PsThreadStep {
  const PsThreadStep({
    required this.title,
    required this.state,
    this.subtitle,
    this.marker = ThreadMarker.step,
  });

  final String title;
  final String? subtitle;
  final ThreadStepState state;
  final ThreadMarker marker;
}

/// SYS-C04 Pick Thread (vertical) — the coral thread connecting completed,
/// current and upcoming steps of an order/tracking timeline.
class PsPickThread extends StatelessWidget {
  const PsPickThread({super.key, required this.steps});

  /// Derives steps from the canonical status: everything on the happy path
  /// before [current] is done. [timestamps] keys are [OrderStatus] values
  /// that actually happened. Exception states are appended as the current node.
  factory PsPickThread.forOrder({
    Key? key,
    required OrderStatus current,
    Map<OrderStatus, String> timestamps = const {},
    List<OrderStatus> path = const [
      OrderStatus.placed,
      OrderStatus.preparing,
      OrderStatus.pickedUp,
      OrderStatus.atSortingCenter,
      OrderStatus.outForDelivery,
      OrderStatus.delivered,
    ],
  }) {
    final steps = <PsThreadStep>[];
    if (current.isException) {
      for (final s in path.where(timestamps.containsKey)) {
        steps.add(PsThreadStep(title: s.buyerLabel, subtitle: timestamps[s], state: ThreadStepState.done));
      }
      steps.add(PsThreadStep(
        title: current.buyerLabel,
        subtitle: timestamps[current],
        state: ThreadStepState.current,
        marker: current.marker,
      ));
    } else {
      final currentIndex = OrderStatus.happyPath.indexOf(current);
      for (final s in path) {
        final i = OrderStatus.happyPath.indexOf(s);
        final state = i < currentIndex
            ? ThreadStepState.done
            : (s == current ? ThreadStepState.current : ThreadStepState.upcoming);
        steps.add(PsThreadStep(title: s.buyerLabel, subtitle: timestamps[s], state: state));
      }
    }
    return PsPickThread(key: key, steps: steps);
  }

  final List<PsThreadStep> steps;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < steps.length; i++)
          _ThreadRow(
            step: steps[i],
            isFirst: i == 0,
            isLast: i == steps.length - 1,
            nextReached: i + 1 < steps.length && steps[i + 1].state != ThreadStepState.upcoming,
          ),
      ],
    );
  }
}

class _ThreadRow extends StatelessWidget {
  const _ThreadRow({
    required this.step,
    required this.isFirst,
    required this.isLast,
    required this.nextReached,
  });

  final PsThreadStep step;
  final bool isFirst;
  final bool isLast;
  final bool nextReached;

  Color get _accent {
    switch (step.marker) {
      case ThreadMarker.warning:
        return PsColors.error;
      case ThreadMarker.returned:
      case ThreadMarker.cancelled:
        return PsColors.textMuted;
      case ThreadMarker.step:
        return PsColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final upcoming = step.state == ThreadStepState.upcoming;
    final current = step.state == ThreadStepState.current;
    final lineColor = nextReached ? PsColors.primary : PsColors.primary.withAlpha(70);

    return Semantics(
      label: '${step.title}${step.subtitle != null ? ', ${step.subtitle}' : ''}'
          '${current ? ', current step' : upcoming ? ', upcoming' : ', completed'}',
      excludeSemantics: true,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 28,
              child: Column(
                children: [
                  const SizedBox(height: 4),
                  _Node(state: step.state, marker: step.marker, accent: _accent),
                  if (!isLast)
                    Expanded(child: Container(width: 2, color: lineColor)),
                ],
              ),
            ),
            const SizedBox(width: PsSpace.sm),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : PsSpace.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.title,
                      style: PsText.bodyStrong.copyWith(
                        fontSize: 15,
                        color: upcoming
                            ? PsColors.textDisabled
                            : current
                                ? _accent
                                : PsColors.textPrimary,
                        fontWeight: upcoming ? FontWeight.w500 : FontWeight.w600,
                      ),
                    ),
                    if (step.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        step.subtitle!,
                        style: PsText.caption.copyWith(
                          color: current ? PsColors.textPrimary : PsColors.textMuted,
                          fontWeight: current ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
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

class _Node extends StatelessWidget {
  const _Node({required this.state, required this.marker, required this.accent});

  final ThreadStepState state;
  final ThreadMarker marker;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case ThreadStepState.done:
        return Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded, size: 11, color: Colors.white),
        );
      case ThreadStepState.current:
        final glyph = switch (marker) {
          ThreadMarker.warning => Icons.priority_high_rounded,
          ThreadMarker.returned => Icons.undo_rounded,
          ThreadMarker.cancelled => Icons.close_rounded,
          ThreadMarker.step => null,
        };
        return Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(color: accent.withAlpha(50), shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            child: glyph == null ? null : Icon(glyph, size: 9, color: Colors.white),
          ),
        );
      case ThreadStepState.upcoming:
        return Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: PsColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: PsColors.border, width: 2),
          ),
        );
    }
  }
}

/// SYS-C04 Pick Thread (linear) — progress through a short onboarding or
/// form flow: "STEP 1 OF 3 · Personal Information" over a coral bar.
class PsStepProgress extends StatelessWidget implements PreferredSizeWidget {
  const PsStepProgress({
    super.key,
    required this.step,
    required this.total,
    required this.label,
  }) : assert(step >= 1 && step <= total);

  /// 1-based.
  final int step;
  final int total;
  final String label;

  @override
  Size get preferredSize => const Size.fromHeight(52);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Step $step of $total, $label',
      excludeSemantics: true,
      child: Container(
        height: preferredSize.height,
        padding: const EdgeInsets.fromLTRB(PsSpace.gutter, 0, PsSpace.gutter, 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'STEP $step OF $total',
                  style: PsText.overline.copyWith(color: PsColors.primaryStrong),
                ),
                const Spacer(),
                Flexible(
                  child: Text(label, style: PsText.caption, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: step / total),
                duration: PsMotion.slow,
                curve: PsMotion.curve,
                builder: (_, value, __) => LinearProgressIndicator(
                  value: value,
                  minHeight: 6,
                  color: PsColors.primary,
                  backgroundColor: PsColors.border,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
