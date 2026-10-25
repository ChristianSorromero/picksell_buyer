import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/ps_colors.dart';
import '../../../core/theme/ps_tokens.dart';
import '../../../core/theme/ps_typography.dart';

/// Inline field error: red icon + message under an input.
class PsFieldError extends StatelessWidget {
  const PsFieldError(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 8, left: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(Icons.error_rounded, size: 15, color: PsColors.error),
            ),
            const SizedBox(width: 6),
            Expanded(child: Text(message, style: PsText.error)),
          ],
        ),
      ),
    );
  }
}

/// Label above a field, with optional trailing widget (e.g. "Forgot password?").
class PsFieldLabel extends StatelessWidget {
  const PsFieldLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(text, style: PsText.label)),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Shared outline styling so every Picksell input looks the same.
InputDecoration psInputDecoration({
  String? hint,
  bool hasError = false,
  Widget? prefix,
  Widget? suffix,
  bool enabled = true,
}) {
  OutlineInputBorder outline(Color color, [double width = 1]) => OutlineInputBorder(
        borderRadius: PsRadius.field,
        borderSide: BorderSide(color: color, width: width),
      );

  return InputDecoration(
    hintText: hint,
    hintStyle: PsText.hint,
    filled: true,
    fillColor: enabled ? PsColors.surface : PsColors.surfaceMuted,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    prefixIcon: prefix,
    prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
    suffixIcon: suffix,
    enabledBorder: outline(hasError ? PsColors.error : PsColors.border),
    disabledBorder: outline(PsColors.border),
    focusedBorder: outline(hasError ? PsColors.error : PsColors.primary, 1.5),
    border: outline(PsColors.border),
  );
}

/// Labeled text input with inline error and built-in password visibility
/// toggle. Errors are driven by [errorText] so the same slot shows client
/// validation and server (Laravel 422) messages.
class PsTextField extends StatefulWidget {
  const PsTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.errorText,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.autofillHints,
    this.obscure = false,
    this.enabled = true,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.prefix,
    this.suffix,
    this.maxLength,
    this.labelTrailing,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? errorText;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;

  /// Password field: obscures text and shows an eye toggle.
  final bool obscure;
  final bool enabled;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? prefix;
  final Widget? suffix;
  final int? maxLength;
  final Widget? labelTrailing;

  @override
  State<PsTextField> createState() => _PsTextFieldState();
}

class _PsTextFieldState extends State<PsTextField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null;
    final toggle = widget.obscure
        ? IconButton(
            tooltip: _hidden ? 'Show password' : 'Hide password',
            onPressed: () => setState(() => _hidden = !_hidden),
            icon: Icon(
              _hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: PsColors.textMuted,
              size: 22,
            ),
          )
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PsFieldLabel(widget.label, trailing: widget.labelTrailing),
        TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          enabled: widget.enabled,
          obscureText: _hidden,
          enableSuggestions: !widget.obscure,
          autocorrect: !widget.obscure,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          textCapitalization: widget.textCapitalization,
          inputFormatters: [
            if (widget.maxLength != null) LengthLimitingTextInputFormatter(widget.maxLength),
            ...?widget.inputFormatters,
          ],
          autofillHints: widget.autofillHints,
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
          style: PsText.input,
          decoration: psInputDecoration(
            hint: widget.hint,
            hasError: hasError,
            enabled: widget.enabled,
            prefix: widget.prefix,
            suffix: widget.suffix ?? toggle,
          ),
        ),
        AnimatedSize(
          duration: PsMotion.fast,
          alignment: Alignment.topLeft,
          child: hasError ? PsFieldError(widget.errorText!) : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
