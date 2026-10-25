import 'package:flutter/material.dart';

import '../../core/theme/ps_colors.dart';
import '../../core/theme/ps_tokens.dart';
import '../../core/theme/ps_typography.dart';

/// Flat bordered card (12pt radius) — the base surface for every grouped
/// block: order info, address, payment details, parcel, actions.
class PsCard extends StatelessWidget {
  const PsCard({
    super.key,
    required this.child,
    this.title,
    this.trailing,
    this.padding = const EdgeInsets.all(PsSpace.md),
    this.onTap,
    this.margin,
    this.color = PsColors.surface,
    this.borderColor = PsColors.border,
  });

  final Widget child;

  /// Overline heading ("SHIPPING ADDRESS").
  final String? title;

  /// Right side of the heading row ("Edit").
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;
  final Color color;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final body = Padding(
      padding: padding,
      child: title == null && trailing == null
          ? child
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    if (title != null) Expanded(child: Text(title!.toUpperCase(), style: PsText.overline)),
                    if (trailing != null) trailing!,
                  ],
                ),
                const SizedBox(height: PsSpace.sm),
                child,
              ],
            ),
    );

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Material(
        color: color,
        shape: RoundedRectangleBorder(borderRadius: PsRadius.card, side: BorderSide(color: borderColor)),
        clipBehavior: Clip.antiAlias,
        child: onTap == null ? body : InkWell(onTap: onTap, child: body),
      ),
    );
  }
}

/// "Order ID ............ PS-88293410"
class PsInfoRow extends StatelessWidget {
  const PsInfoRow({super.key, required this.label, required this.value, this.valueWidget, this.emphasize = false});

  final String label;
  final String value;
  final Widget? valueWidget;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: PsText.bodyMuted)),
          const SizedBox(width: PsSpace.sm),
          Flexible(
            child: valueWidget ??
                Text(
                  value,
                  textAlign: TextAlign.right,
                  style: emphasize ? PsText.bodyStrong : PsText.body.copyWith(fontWeight: FontWeight.w600),
                ),
          ),
        ],
      ),
    );
  }
}

/// Radio-style option card: coral border + filled radio when selected,
/// muted with a "Coming soon" chip when [enabled] is false.
class PsSelectableCard extends StatelessWidget {
  const PsSelectableCard({
    super.key,
    required this.selected,
    required this.child,
    this.onTap,
    this.enabled = true,
  });

  final bool selected;
  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      enabled: enabled,
      inMutuallyExclusiveGroup: true,
      button: true,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: AnimatedContainer(
          duration: PsMotion.fast,
          decoration: BoxDecoration(
            color: enabled ? PsColors.surface : PsColors.surfaceMuted,
            borderRadius: PsRadius.card,
            border: Border.all(color: selected ? PsColors.primary : PsColors.border, width: selected ? 1.6 : 1),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: PsRadius.card,
              onTap: enabled ? onTap : null,
              child: Padding(
                padding: const EdgeInsets.all(PsSpace.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: child),
                    const SizedBox(width: PsSpace.sm),
                    _Radio(selected: selected),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: PsMotion.fast,
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: selected ? PsColors.primary : PsColors.border, width: 2),
      ),
      alignment: Alignment.center,
      child: AnimatedContainer(
        duration: PsMotion.fast,
        width: selected ? 11 : 0,
        height: selected ? 11 : 0,
        decoration: const BoxDecoration(color: PsColors.primary, shape: BoxShape.circle),
      ),
    );
  }
}

/// Small rounded tag: "OFFICIAL", "RECOMMENDED", "Coming Soon", "WORK".
class PsTag extends StatelessWidget {
  const PsTag(this.label, {super.key, this.color = PsColors.primaryStrong, this.background = PsColors.primarySoft, this.icon});

  const PsTag.muted(this.label, {super.key, this.icon})
      : color = PsColors.textMuted,
        background = PsColors.neutralSoft;

  final String label;
  final Color color;
  final Color background;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(4)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 3)],
          Text(label, style: PsText.badge.copyWith(color: color, fontSize: 10.5)),
        ],
      ),
    );
  }
}
