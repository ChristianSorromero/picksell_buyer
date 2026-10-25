import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/ps_colors.dart';
import '../../../core/theme/ps_tokens.dart';
import '../../../core/theme/ps_typography.dart';

/// Six-box one-time-code input. Backed by a single hidden [TextField] so
/// paste, SMS/email autofill and backspace across boxes all work.
class PsOtpInput extends StatefulWidget {
  const PsOtpInput({
    super.key,
    required this.controller,
    this.length = 6,
    this.hasError = false,
    this.enabled = true,
    this.autofocus = true,
    this.onChanged,
    this.onCompleted,
  });

  final TextEditingController controller;
  final int length;
  final bool hasError;
  final bool enabled;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCompleted;

  @override
  State<PsOtpInput> createState() => _PsOtpInputState();
}

class _PsOtpInputState extends State<PsOtpInput> {
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
    widget.controller.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    _focus.dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final code = widget.controller.text;
    return Semantics(
      label: 'Verification code, ${code.length} of ${widget.length} digits entered',
      textField: true,
      child: GestureDetector(
        onTap: () => _focus.requestFocus(),
        child: Stack(
          children: [
            // Invisible input that actually owns the keyboard.
            Positioned.fill(
              child: Opacity(
                opacity: 0,
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  enabled: widget.enabled,
                  autofocus: widget.autofocus,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  showCursor: false,
                  enableInteractiveSelection: false,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(widget.length),
                  ],
                  onChanged: (v) {
                    widget.onChanged?.call(v);
                    if (v.length == widget.length) widget.onCompleted?.call(v);
                  },
                ),
              ),
            ),
            IgnorePointer(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i < widget.length; i++)
                    _Box(
                      digit: i < code.length ? code[i] : '',
                      active: _focus.hasFocus && i == code.length.clamp(0, widget.length - 1),
                      hasError: widget.hasError,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.digit, required this.active, required this.hasError});

  final String digit;
  final bool active;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final color = hasError
        ? PsColors.error
        : active
            ? PsColors.primary
            : digit.isNotEmpty
                ? PsColors.textMuted
                : PsColors.border;
    return AnimatedContainer(
      duration: PsMotion.fast,
      width: 46,
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: PsColors.surface,
        borderRadius: PsRadius.field,
        border: Border.all(color: color, width: hasError || active ? 1.8 : 1.2),
      ),
      child: Text(digit, style: PsText.otpDigit),
    );
  }
}
