import 'package:flutter/material.dart';

import '../../core/theme/ps_colors.dart';
import '../../core/theme/ps_tokens.dart';
import '../../core/theme/ps_typography.dart';

/// One selectable row in [PsBottomSheet.options].
class PsSheetOption<T> {
  const PsSheetOption({
    required this.value,
    required this.label,
    this.icon,
    this.description,
    this.destructive = false,
  });

  final T value;
  final String label;
  final IconData? icon;
  final String? description;
  final bool destructive;
}

/// SYS-C10 Bottom Sheet — contextual choices without leaving the screen.
class PsBottomSheet {
  PsBottomSheet._();

  /// Free-form sheet with a grab handle and optional title.
  static Future<T?> show<T>(
    BuildContext context, {
    String? title,
    required WidgetBuilder builder,
    bool scrollControlled = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: scrollControlled,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: _SheetFrame(title: title, child: builder(ctx)),
      ),
    );
  }

  /// Option list (camera vs gallery, sort order…). Resolves to the chosen
  /// value, or null when dismissed. [selected] gets a check mark.
  static Future<T?> options<T>(
    BuildContext context, {
    String? title,
    required List<PsSheetOption<T>> options,
    T? selected,
  }) {
    return show<T>(
      context,
      title: title,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final o in options)
            ListTile(
              minTileHeight: 52,
              contentPadding: const EdgeInsets.symmetric(horizontal: PsSpace.gutter),
              leading: o.icon == null
                  ? null
                  : Icon(o.icon, color: o.destructive ? PsColors.error : PsColors.textPrimary),
              title: Text(
                o.label,
                style: PsText.bodyStrong.copyWith(color: o.destructive ? PsColors.error : null),
              ),
              subtitle: o.description == null ? null : Text(o.description!, style: PsText.caption),
              trailing: o.value == selected
                  ? const Icon(Icons.check_rounded, color: PsColors.primaryStrong)
                  : null,
              onTap: () => Navigator.of(ctx).pop(o.value),
            ),
        ],
      ),
    );
  }
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.title, required this.child});

  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: PsSpace.xs),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: PsColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(PsSpace.gutter, PsSpace.md, PsSpace.gutter, PsSpace.xs),
              child: Text(title!, style: PsText.heading),
            )
          else
            const SizedBox(height: PsSpace.xs),
          Flexible(child: child),
          const SizedBox(height: PsSpace.xs),
        ],
      ),
    );
  }
}
