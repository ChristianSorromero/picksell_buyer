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
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: preferredSize.height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(PsSpace.gutter, 4, PsSpace.gutter, 8),
        itemCount: segments.length,
        separatorBuilder: (_, __) => const SizedBox(width: PsSpace.xs),
        itemBuilder: (_, i) => _SegmentTab(segment: segments[i], selected: segments[i].value == selected, onTap: () => onChanged(segments[i].value)),
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
    final fg = selected ? PsColors.surface : PsColors.textPrimary;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PsRadius.pill),
        child: AnimatedContainer(
          duration: PsMotion.fast,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? PsColors.textPrimary : PsColors.surface,
            borderRadius: BorderRadius.circular(PsRadius.pill),
            border: Border.all(color: selected ? PsColors.textPrimary : PsColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                Container(width: 6, height: 6, decoration: BoxDecoration(color: PsColors.primary, shape: BoxShape.circle)),
                const SizedBox(width: 8),
              ],
              Text(segment.label, style: PsText.ui.copyWith(color: fg)),
              if (segment.count != null) ...[
                const SizedBox(width: 6),
                Container(
                  constraints: const BoxConstraints(minWidth: 20),
                  height: 20,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: PsColors.primary, borderRadius: BorderRadius.circular(10)),
                  child: Text('${segment.count}', style: PsText.badge.copyWith(color: PsColors.onPrimary)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
