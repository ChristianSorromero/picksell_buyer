import 'package:flutter/material.dart';

import '../../core/theme/ps_colors.dart';
import '../../core/theme/ps_tokens.dart';
import '../../core/theme/ps_typography.dart';

class PsSegment<T> {
  const PsSegment(this.value, this.label, {this.count});

  final T value;
  final String label;

  /// Optional count shown after the label, e.g. "To Ship (2)".
  final int? count;
}

/// SYS-C19 Segmented Control — switches between related datasets
/// (To Ship / In Transit / Out for Delivery / To Rate) on one screen.
/// Scrolls horizontally when segments don't fit.
class PsSegmentedControl<T> extends StatelessWidget implements PreferredSizeWidget {
  const PsSegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final List<PsSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Size get preferredSize => const Size.fromHeight(48);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: preferredSize.height,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: PsColors.border)),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: PsSpace.xs),
        children: [
          for (final s in segments) _SegmentTab(segment: s, selected: s.value == selected, onTap: () => onChanged(s.value)),
        ],
      ),
    );
  }
}

class _SegmentTab<T> extends StatelessWidget {
  const _SegmentTab({required this.segment, required this.selected, required this.onTap});

  final PsSegment<T> segment;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = segment.count == null ? segment.label : '${segment.label} (${segment.count})';
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                label,
                style: PsText.body.copyWith(
                  color: selected ? PsColors.primary : PsColors.textMuted,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
              AnimatedContainer(
                duration: PsMotion.normal,
                curve: PsMotion.curve,
                height: 3,
                width: selected ? 28 : 0,
                decoration: BoxDecoration(
                  color: PsColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
