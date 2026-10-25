import 'package:flutter/material.dart';

import '../../core/theme/ps_colors.dart';
import '../../core/theme/ps_tokens.dart';
import '../../core/theme/ps_typography.dart';

/// SYS-C06 Primary Action Button — the one main action on a screen.
///
/// Disabled when [onPressed] is null; shows a spinner and ignores taps while
/// [loading] so a request can't be submitted twice.
class PsPrimaryButton extends StatelessWidget {
  const PsPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.trailingIcon,
    this.uppercase = true,
    this.expand = true,
    this.height = PsSize.buttonHeight,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final IconData? trailingIcon;

  /// Form CTAs ("CONTINUE") are uppercase; in-card actions ("Track Order") aren't.
  final bool uppercase;
  final bool expand;
  final double height;

  bool get _enabled => onPressed != null && !loading;

  @override
  Widget build(BuildContext context) {
    final style = PsText.button;
    final content = loading
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: PsColors.onPrimary),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
              Flexible(
                child: Text(
                  uppercase ? label.toUpperCase() : label,
                  overflow: TextOverflow.ellipsis,
                  style: uppercase ? style : style.copyWith(letterSpacing: 0),
                ),
              ),
              if (trailingIcon != null) ...[const SizedBox(width: 8), Icon(trailingIcon, size: 18)],
            ],
          );

    return Semantics(
      button: true,
      enabled: _enabled,
      label: label,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: PsMotion.fast,
        height: height,
        width: expand ? double.infinity : null,
        decoration: BoxDecoration(
          borderRadius: PsRadius.button,
          boxShadow: _enabled
              ? [
                  BoxShadow(
                    color: PsColors.primary.withAlpha(70),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: ElevatedButton(
          onPressed: _enabled ? onPressed : (loading ? () {} : null),
          style: ElevatedButton.styleFrom(
            backgroundColor: PsColors.primary,
            foregroundColor: PsColors.onPrimary,
            disabledBackgroundColor: PsColors.primary.withAlpha(110),
            disabledForegroundColor: PsColors.onPrimary.withAlpha(140),
            elevation: 0,
            minimumSize: const Size(PsSize.minTap, PsSize.minTap),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            shape: RoundedRectangleBorder(borderRadius: PsRadius.button),
          ),
          child: content,
        ),
      ),
    );
  }
}

enum PsSecondaryVariant { outlined, text }

/// SYS-C07 Secondary Action Button — supporting/alternative actions
/// ("Back", "Rate", "Return to login") that never compete with the primary.
class PsSecondaryButton extends StatelessWidget {
  const PsSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = PsSecondaryVariant.text,
    this.icon,
    this.expand = false,
    this.destructive = false,
  });

  const PsSecondaryButton.outlined({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = false,
    this.destructive = false,
  }) : variant = PsSecondaryVariant.outlined;

  final String label;
  final VoidCallback? onPressed;
  final PsSecondaryVariant variant;
  final IconData? icon;
  final bool expand;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? PsColors.error : PsColors.primaryStrong;
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 6)],
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    );

    final button = variant == PsSecondaryVariant.outlined
        ? OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: destructive ? PsColors.error : PsColors.textPrimary,
              backgroundColor: PsColors.surface,
              textStyle: PsText.bodyStrong,
              minimumSize: const Size(PsSize.minTap, PsSize.minTap),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              side: const BorderSide(color: PsColors.border),
              shape: RoundedRectangleBorder(borderRadius: PsRadius.button),
            ),
            child: child,
          )
        : TextButton(
            onPressed: onPressed,
            style: TextButton.styleFrom(
              foregroundColor: color,
              textStyle: PsText.link,
              minimumSize: const Size(PsSize.minTap, PsSize.minTap),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(borderRadius: PsRadius.button),
            ),
            child: child,
          );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// SYS-C08 Icon Button — compact secondary actions (search, notifications,
/// cart, save, more). Always a 44pt target; optional count badge or dot.
class PsIconButton extends StatelessWidget {
  const PsIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.badgeCount,
    this.showDot = false,
    this.color = PsColors.textPrimary,
    this.size = PsSize.icon,
    this.filled = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  /// Also used as the accessibility label.
  final String tooltip;
  final int? badgeCount;
  final bool showDot;
  final Color color;
  final double size;

  /// White circular chip behind the icon (e.g. over product images).
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final count = badgeCount ?? 0;
    Widget glyph = Icon(icon, size: size, color: color);

    if (count > 0 || showDot) {
      glyph = Badge(
        isLabelVisible: true,
        backgroundColor: PsColors.primary,
        textColor: PsColors.onPrimary,
        smallSize: 8,
        label: count > 0 ? Text(count > 99 ? '99+' : '$count') : null,
        child: glyph,
      );
    }

    return Tooltip(
      message: tooltip,
      child: Material(
        type: filled ? MaterialType.circle : MaterialType.transparency,
        color: filled ? PsColors.surface.withAlpha(235) : null,
        elevation: 0,
        child: InkResponse(
          onTap: onPressed,
          radius: PsSize.minTap / 2 + 2,
          child: SizedBox.square(
            dimension: PsSize.minTap,
            child: Center(child: glyph),
          ),
        ),
      ),
    );
  }
}
