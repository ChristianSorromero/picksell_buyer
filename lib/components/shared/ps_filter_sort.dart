import 'package:flutter/material.dart';

import '../../core/theme/ps_colors.dart';
import '../../core/theme/ps_tokens.dart';
import '../../core/theme/ps_typography.dart';
import 'ps_bottom_sheet.dart';

/// One chip in [PsFilterChips].
class PsFilterOption<T> {
  const PsFilterOption(this.value, this.label);

  final T value;
  final String label;
}

/// SYS-C18 Filter control — horizontally scrolling single-select chips
/// ("All Categories", "Electronics", …). Selected chip is solid dark.
class PsFilterChips<T> extends StatelessWidget {
  const PsFilterChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<PsFilterOption<T>> options;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: PsSize.minTap,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: PsSpace.page,
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: PsSpace.xs),
        itemBuilder: (_, i) {
          final o = options[i];
          final isSelected = o.value == selected;
          return Semantics(
            selected: isSelected,
            button: true,
            child: Center(
              child: InkWell(
                onTap: () => onSelected(o.value),
                borderRadius: BorderRadius.circular(PsRadius.pill),
                child: AnimatedContainer(
                  duration: PsMotion.fast,
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? PsColors.textPrimary : PsColors.surface,
                    borderRadius: BorderRadius.circular(PsRadius.pill),
                    border: Border.all(color: isSelected ? PsColors.textPrimary : PsColors.border),
                  ),
                  child: Text(
                    o.label,
                    style: PsText.caption.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : PsColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// On/off filter chip ("On sale") styled like [PsFilterChips].
class PsToggleChip extends StatelessWidget {
  const PsToggleChip({super.key, required this.label, required this.selected, required this.onChanged, this.icon});

  final String label;
  final bool selected;
  final ValueChanged<bool> onChanged;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : PsColors.textPrimary;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: () => onChanged(!selected),
        borderRadius: BorderRadius.circular(PsRadius.pill),
        child: AnimatedContainer(
          duration: PsMotion.fast,
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? PsColors.textPrimary : PsColors.surface,
            borderRadius: BorderRadius.circular(PsRadius.pill),
            border: Border.all(color: selected ? PsColors.textPrimary : PsColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon ?? (selected ? Icons.check_rounded : Icons.local_offer_outlined), size: 16, color: fg),
              const SizedBox(width: 6),
              Text(label, style: PsText.caption.copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

/// SYS-C18 Sort control — compact button showing the current order that
/// opens a [PsBottomSheet] of choices.
class PsSortButton<T> extends StatelessWidget {
  const PsSortButton({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<PsFilterOption<T>> options;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final current = options.firstWhere((o) => o.value == selected, orElse: () => options.first);
    return TextButton.icon(
      onPressed: () async {
        final picked = await PsBottomSheet.options<T>(
          context,
          title: 'Sort by',
          selected: selected,
          options: [for (final o in options) PsSheetOption(value: o.value, label: o.label)],
        );
        if (picked != null) onSelected(picked);
      },
      style: TextButton.styleFrom(
        foregroundColor: PsColors.textPrimary,
        minimumSize: const Size(PsSize.minTap, PsSize.minTap),
        textStyle: PsText.caption.copyWith(fontWeight: FontWeight.w600, fontSize: 13),
      ),
      icon: const Icon(Icons.swap_vert_rounded, size: 18),
      label: Text(current.label),
    );
  }
}
