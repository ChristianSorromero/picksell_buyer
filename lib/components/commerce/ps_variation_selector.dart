import 'package:flutter/material.dart';

import '../../core/theme/ps_colors.dart';
import '../../core/theme/ps_tokens.dart';
import '../../core/theme/ps_typography.dart';
import '../../models/catalog.dart';

/// COM-C09 Variation Selector — one row of option chips per variation type
/// (Color, Size…). Sold-out options are disabled. [selected] maps type →
/// chosen option id.
class PsVariationSelector extends StatelessWidget {
  const PsVariationSelector({
    super.key,
    required this.groups,
    required this.selected,
    required this.onChanged,
    this.missing = const {},
  });

  final List<VariationGroup> groups;
  final Map<String, int> selected;
  final void Function(String type, int optionId) onChanged;

  /// Types the user tried to skip — highlighted with an error hint.
  final Set<String> missing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final group in groups) ...[
          Row(
            children: [
              Text(group.name, style: PsText.label),
              if (missing.contains(group.name)) ...[
                const SizedBox(width: PsSpace.xs),
                Text('Please select', style: PsText.error),
              ],
            ],
          ),
          const SizedBox(height: PsSpace.xs),
          Wrap(
            spacing: PsSpace.xs,
            runSpacing: PsSpace.xs,
            children: [
              for (final option in group.options)
                PsOptionChip(
                  label: option.value,
                  selected: selected[group.name] == option.id,
                  enabled: option.stock > 0,
                  onTap: () => onChanged(group.name, option.id),
                ),
            ],
          ),
          const SizedBox(height: PsSpace.md),
        ],
      ],
    );
  }
}

/// Black-when-selected choice chip with a coral underline (Figma COM-C09).
class PsOptionChip extends StatelessWidget {
  const PsOptionChip({super.key, required this.label, required this.selected, required this.onTap, this.enabled = true});

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      enabled: enabled,
      button: true,
      label: enabled ? label : '$label, sold out',
      excludeSemantics: true,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: PsMotion.fast,
          constraints: const BoxConstraints(minWidth: 96, minHeight: PsSize.minTap),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? PsColors.textPrimary : (enabled ? PsColors.surface : PsColors.surfaceMuted),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? PsColors.textPrimary : PsColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: PsText.caption.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : (enabled ? PsColors.textPrimary : PsColors.textDisabled),
                  decoration: enabled ? null : TextDecoration.lineThrough,
                ),
              ),
              if (selected) ...[
                const SizedBox(height: 3),
                Container(width: 16, height: 2, color: PsColors.primary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
