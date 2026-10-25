import 'package:flutter/material.dart';

import '../../../core/theme/ps_colors.dart';
import '../../../core/theme/ps_typography.dart';
import '../../../core/validation/validators.dart';

/// Live password requirement list: green check when met, grey ring when not.
class PsPasswordChecklist extends StatelessWidget {
  const PsPasswordChecklist({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, left: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final rule in PasswordRule.values) _RuleRow(rule: rule, met: rule.isMetBy(password)),
        ],
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.rule, required this.met});

  final PasswordRule rule;
  final bool met;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${rule.label}, ${met ? 'met' : 'not met'}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
              child: Icon(
                met ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                key: ValueKey(met),
                size: 16,
                color: met ? PsColors.success : PsColors.textMuted,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                rule.label,
                style: PsText.caption.copyWith(
                  fontSize: 13,
                  color: met ? PsColors.success : PsColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
