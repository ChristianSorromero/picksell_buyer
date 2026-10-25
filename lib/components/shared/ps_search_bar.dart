import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/ps_colors.dart';
import '../../core/theme/ps_tokens.dart';
import '../../core/theme/ps_typography.dart';

/// SYS-C17 Search Component.
///
/// Use [readOnly] + [onTap] on the home bar to open a dedicated search
/// screen; use [onChanged] (debounced by [debounce]) for in-place filtering.
class PsSearchBar extends StatefulWidget {
  const PsSearchBar({
    super.key,
    this.hint = 'Search Picksell…',
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.readOnly = false,
    this.autofocus = false,
    this.debounce = const Duration(milliseconds: 300),
  });

  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final bool readOnly;
  final bool autofocus;
  final Duration debounce;

  @override
  State<PsSearchBar> createState() => _PsSearchBarState();
}

class _PsSearchBarState extends State<PsSearchBar> {
  late final TextEditingController _controller = widget.controller ?? TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onText);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onText);
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  void _onText() {
    setState(() {}); // toggles the clear button
    if (widget.onChanged == null) return;
    _debounce?.cancel();
    _debounce = Timer(widget.debounce, () => widget.onChanged!(_controller.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: PsRadius.field,
      borderSide: const BorderSide(color: PsColors.border),
    );
    return SizedBox(
      height: PsSize.minTap,
      child: TextField(
        controller: _controller,
        readOnly: widget.readOnly,
        autofocus: widget.autofocus,
        onTap: widget.onTap,
        onSubmitted: widget.onSubmitted,
        textInputAction: TextInputAction.search,
        style: PsText.input.copyWith(fontSize: 14),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: PsText.hint.copyWith(fontSize: 14),
          filled: true,
          fillColor: PsColors.surface,
          contentPadding: EdgeInsets.zero,
          prefixIcon: const Icon(Icons.search_rounded, color: PsColors.textHint, size: 22),
          suffixIcon: _controller.text.isEmpty || widget.readOnly
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.close_rounded, size: 18, color: PsColors.textMuted),
                  onPressed: () {
                    _controller.clear();
                    widget.onSubmitted?.call('');
                  },
                ),
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: const BorderSide(color: PsColors.primary, width: 1.4),
          ),
        ),
      ),
    );
  }
}
