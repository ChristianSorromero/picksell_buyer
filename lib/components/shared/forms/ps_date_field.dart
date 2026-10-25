import 'package:flutter/material.dart';

import '../../../core/theme/ps_colors.dart';
import '../../../core/theme/ps_tokens.dart';
import '../../../core/theme/ps_typography.dart';
import 'ps_text_field.dart';

/// Labeled date input that opens the platform date picker. Shows
/// "MM / DD / YYYY" and the same inline error slot as [PsTextField].
class PsDateField extends StatelessWidget {
  const PsDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.errorText,
    this.firstDate,
    this.lastDate,
    this.initialDate,
    this.helpText,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final String? errorText;
  final DateTime? firstDate;
  final DateTime? lastDate;

  /// Where the picker opens when [value] is null.
  final DateTime? initialDate;
  final String? helpText;

  static String format(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')} / ${d.day.toString().padLeft(2, '0')} / ${d.year}';

  Future<void> _pick(BuildContext context) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final now = DateTime.now();
    final last = lastDate ?? now;
    final first = firstDate ?? DateTime(1900);
    var initial = value ?? initialDate ?? last;
    if (initial.isAfter(last)) initial = last;
    if (initial.isBefore(first)) initial = first;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      helpText: helpText,
      initialEntryMode: DatePickerEntryMode.calendar,
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PsFieldLabel(label),
        Semantics(
          button: true,
          label: '$label, ${value == null ? 'not set' : format(value!)}',
          excludeSemantics: true,
          child: InkWell(
            onTap: () => _pick(context),
            borderRadius: PsRadius.field,
            child: InputDecorator(
              isEmpty: value == null,
              decoration: psInputDecoration(
                hint: 'MM / DD / YYYY',
                hasError: hasError,
                suffix: const Icon(Icons.calendar_month_outlined, color: PsColors.textHint),
              ),
              child: Text(value == null ? '' : format(value!), style: PsText.input),
            ),
          ),
        ),
        AnimatedSize(
          duration: PsMotion.fast,
          alignment: Alignment.topLeft,
          child: hasError ? PsFieldError(errorText!) : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
