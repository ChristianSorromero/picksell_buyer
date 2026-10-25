import 'package:flutter/material.dart';

import '../../core/theme/ps_colors.dart';
import '../../core/theme/ps_tokens.dart';
import '../../core/theme/ps_typography.dart';

/// COM-C08 Quantity Stepper — never below [min] or above [max] (stock).
/// [compact] is the small cart-line variant; the default is the full-width
/// sheet variant.
class PsQuantityStepper extends StatelessWidget {
  const PsQuantityStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    required this.max,
    this.compact = false,
    this.enabled = true,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final bool compact;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final canDec = enabled && value > min;
    final canInc = enabled && value < max;
    final h = compact ? 32.0 : 52.0;

    Widget button(IconData icon, bool active, VoidCallback onTap, String label) => Semantics(
          button: true,
          enabled: active,
          label: label,
          child: InkWell(
            onTap: active ? onTap : null,
            child: Container(
              width: compact ? 32 : 64,
              height: h,
              color: PsColors.surfaceMuted,
              alignment: Alignment.center,
              child: Icon(icon, size: compact ? 16 : 20, color: active ? PsColors.textPrimary : PsColors.textDisabled),
            ),
          ),
        );

    return Container(
      height: h,
      decoration: BoxDecoration(
        color: PsColors.surface,
        borderRadius: BorderRadius.circular(compact ? 8 : PsRadius.md),
        border: Border.all(color: PsColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
        children: [
          button(Icons.remove_rounded, canDec, () => onChanged(value - 1), 'Decrease quantity'),
          if (compact)
            SizedBox(width: 36, child: Center(child: Text('$value', style: PsText.bodyStrong)))
          else
            Expanded(
              child: Semantics(
                label: 'Quantity $value',
                child: Center(child: Text('$value', style: PsText.heading.copyWith(fontSize: 17))),
              ),
            ),
          button(Icons.add_rounded, canInc, () => onChanged(value + 1), 'Increase quantity'),
        ],
      ),
    );
  }
}
