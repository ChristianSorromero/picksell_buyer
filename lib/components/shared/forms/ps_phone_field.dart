import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/ps_colors.dart';
import '../../../core/theme/ps_typography.dart';
import 'ps_text_field.dart';

/// Philippine mobile number input with a fixed "+63" prefix. Displays
/// "917 123 4567"; read the bare digits with [PsPhoneField.digitsOf].
class PsPhoneField extends StatelessWidget {
  const PsPhoneField({
    super.key,
    required this.controller,
    this.label = 'Mobile Number',
    this.errorText,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction = TextInputAction.done,
  });

  final TextEditingController controller;
  final String label;
  final String? errorText;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction textInputAction;

  /// "917 123 4567" -> "9171234567".
  static String digitsOf(String text) => text.replaceAll(RegExp(r'\D'), '');

  /// "9171234567" -> "09171234567" (format the Laravel API expects).
  static String toLocalFormat(String digits) => '0$digits';

  @override
  Widget build(BuildContext context) {
    return PsTextField(
      label: label,
      controller: controller,
      hint: '917 123 4567',
      errorText: errorText,
      focusNode: focusNode,
      keyboardType: TextInputType.phone,
      textInputAction: textInputAction,
      autofillHints: const [AutofillHints.telephoneNumberNational],
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      inputFormatters: [_PhMobileFormatter()],
      prefix: Padding(
        padding: const EdgeInsets.only(left: 16, right: 12),
        child: IntrinsicHeight(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('+63', style: PsText.input.copyWith(fontWeight: FontWeight.w600, color: PsColors.textSecondary)),
              const SizedBox(width: 12),
              const VerticalDivider(width: 1, thickness: 1, color: PsColors.border, indent: 2, endIndent: 2),
            ],
          ),
        ),
      ),
    );
  }
}

/// Keeps only digits, drops a leading 0 or 63 (pasted "0917…"/"+63917…"),
/// caps at 10 digits and groups as 3-3-4.
class _PhMobileFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('63') && digits.length > 10) digits = digits.substring(2);
    if (digits.startsWith('0')) digits = digits.substring(1);
    if (digits.length > 10) digits = digits.substring(0, 10);

    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i == 3 || i == 6) buffer.write(' ');
      buffer.write(digits[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}
