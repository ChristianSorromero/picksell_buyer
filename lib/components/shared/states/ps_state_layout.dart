import 'package:flutter/material.dart';

import '../../../core/theme/ps_colors.dart';
import '../../../core/theme/ps_tokens.dart';
import '../../../core/theme/ps_typography.dart';
import '../ps_motion.dart';

/// Icon-in-halo + title + message + optional action. Shared layout for the
/// empty, error and offline states and for dialog headers.
class PsStateLayout extends StatelessWidget {
  const PsStateLayout({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.iconColor = PsColors.primary,
    this.haloColor,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final Color iconColor;
  final Color? haloColor;

  /// Smaller halo and spacing for use inside cards or dialogs.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final halo = compact ? 64.0 : 96.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The halo pops in once; the text follows with a short rise.
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.6, end: 1),
          duration: PsMotion.duration(context, PsMotion.slow),
          curve: Curves.easeOutBack,
          builder: (_, s, child) => Transform.scale(scale: s, child: child),
          child: Container(
            width: halo,
            height: halo,
            decoration: BoxDecoration(color: haloColor ?? PsColors.primarySoft, shape: BoxShape.circle),
            child: Icon(icon, size: halo * 0.42, color: iconColor),
          ),
        ),
        SizedBox(height: compact ? PsSpace.md : PsSpace.lg),
        PsFadeIn(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: compact ? PsText.heading.copyWith(fontSize: 17) : PsText.display.copyWith(fontSize: 22),
              ),
              if (message != null) ...[
                const SizedBox(height: PsSpace.xs),
                Text(message!, textAlign: TextAlign.center, style: PsText.subtitle),
              ],
              if (action != null) ...[SizedBox(height: compact ? PsSpace.md : PsSpace.lg), action!],
            ],
          ),
        ),
      ],
    );
  }
}

/// Centers [child] in the available space, scrolling if it doesn't fit
/// (so states also work inside pull-to-refresh lists).
class PsCenteredScrollable extends StatelessWidget {
  const PsCenteredScrollable({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: PsSpace.lg, vertical: PsSpace.xl),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: (constraints.maxHeight - PsSpace.xl * 2).clamp(0, double.infinity)),
          child: Center(child: child),
        ),
      ),
    );
  }
}
