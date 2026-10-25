import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/ps_colors.dart';
import '../../../core/theme/ps_typography.dart';
import 'ps_text_field.dart';

/// A tappable span inside [PsCheckboxTile]'s label.
class PsInlineLink {
  const PsInlineLink(this.text, this.onTap);

  final String text;
  final VoidCallback onTap;
}

/// Consent checkbox whose label can mix plain text and links:
/// `['I agree to the ', PsInlineLink('Terms of Service', …), ' and ', …]`.
class PsCheckboxTile extends StatefulWidget {
  const PsCheckboxTile({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    this.errorText,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  /// Mix of [String] and [PsInlineLink].
  final List<Object> label;
  final String? errorText;

  @override
  State<PsCheckboxTile> createState() => _PsCheckboxTileState();
}

class _PsCheckboxTileState extends State<PsCheckboxTile> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  List<InlineSpan> _spans() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
    return [
      for (final part in widget.label)
        if (part is PsInlineLink)
          TextSpan(
            text: part.text,
            style: PsText.link.copyWith(
              decoration: TextDecoration.underline,
              decorationColor: PsColors.primaryStrong,
            ),
            recognizer: (TapGestureRecognizer()..onTap = part.onTap).also(_recognizers.add),
          )
        else
          TextSpan(text: part.toString()),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => widget.onChanged(!widget.value),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 44,
                  height: 44,
                  child: Checkbox(
                    value: widget.value,
                    onChanged: (v) => widget.onChanged(v ?? false),
                    activeColor: PsColors.surface,
                    checkColor: PsColors.primaryStrong,
                    side: WidgetStateBorderSide.resolveWith(
                      (states) => BorderSide(
                        color: hasError
                            ? PsColors.error
                            : states.contains(WidgetState.selected)
                                ? PsColors.primaryStrong
                                : PsColors.textMuted,
                        width: 1.6,
                      ),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 11),
                    child: Text.rich(
                      TextSpan(style: PsText.body.copyWith(color: PsColors.textSecondary), children: _spans()),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (hasError) PsFieldError(widget.errorText!),
      ],
    );
  }
}

extension _Also<T> on T {
  T also(void Function(T) f) {
    f(this);
    return this;
  }
}
