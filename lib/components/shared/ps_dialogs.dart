import 'package:flutter/material.dart';

import '../../core/theme/ps_colors.dart';
import '../../core/theme/ps_tokens.dart';
import 'ps_buttons.dart';
import 'states/ps_state_layout.dart';

/// SYS-C09 Confirmation Dialog and the error/info popups.
///
/// ```dart
/// final ok = await PsDialog.confirm(context,
///     title: 'Cancel order?', message: '…', confirmLabel: 'Cancel order',
///     destructive: true);
/// await PsDialog.error(context, title: 'Couldn’t create account', message: e);
/// ```
class PsDialog {
  PsDialog._();

  /// Guards consequential actions. Resolves `true` only on explicit confirm.
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    String cancelLabel = 'Not now',
    bool destructive = false,
    IconData icon = Icons.help_outline_rounded,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => _PsDialogFrame(
        icon: destructive ? Icons.warning_amber_rounded : icon,
        iconColor: destructive ? PsColors.error : PsColors.primary,
        haloColor: destructive ? PsColors.errorSoft : PsColors.primarySoft,
        title: title,
        message: message,
        actions: [
          PsPrimaryButton(
            label: confirmLabel,
            uppercase: false,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
          PsSecondaryButton(
            label: cancelLabel,
            expand: true,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Blocking error popup for failures the user must acknowledge
  /// (inline field errors should use the field's `errorText` instead).
  static Future<void> error(
    BuildContext context, {
    required String title,
    required String message,
    String actionLabel = 'OK',
    String? secondaryLabel,
    VoidCallback? onSecondary,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => _PsDialogFrame(
        icon: Icons.error_outline_rounded,
        iconColor: PsColors.error,
        haloColor: PsColors.errorSoft,
        title: title,
        message: message,
        actions: [
          PsPrimaryButton(
            label: actionLabel,
            uppercase: false,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          if (secondaryLabel != null)
            PsSecondaryButton(
              label: secondaryLabel,
              expand: true,
              onPressed: () {
                Navigator.of(ctx).pop();
                onSecondary?.call();
              },
            ),
        ],
      ),
    );
  }

  /// Neutral/success popup.
  static Future<void> info(
    BuildContext context, {
    required String title,
    required String message,
    String actionLabel = 'OK',
    IconData icon = Icons.check_circle_outline_rounded,
    bool success = true,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => _PsDialogFrame(
        icon: icon,
        iconColor: success ? PsColors.success : PsColors.primary,
        haloColor: success ? PsColors.successSoft : PsColors.primarySoft,
        title: title,
        message: message,
        actions: [
          PsPrimaryButton(
            label: actionLabel,
            uppercase: false,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }
}

class _PsDialogFrame extends StatelessWidget {
  const _PsDialogFrame({
    required this.icon,
    required this.iconColor,
    required this.haloColor,
    required this.title,
    required this.message,
    required this.actions,
  });

  final IconData icon;
  final Color iconColor;
  final Color haloColor;
  final String title;
  final String message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: PsSpace.lg),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(PsSpace.lg, PsSpace.lg, PsSpace.lg, PsSpace.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PsStateLayout(
              compact: true,
              icon: icon,
              iconColor: iconColor,
              haloColor: haloColor,
              title: title,
              message: message,
            ),
            const SizedBox(height: PsSpace.lg),
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) const SizedBox(height: PsSpace.xxs),
              actions[i],
            ],
          ],
        ),
      ),
    );
  }
}
