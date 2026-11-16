import 'package:flutter/material.dart';

import '../ps_buttons.dart';
import 'ps_state_layout.dart';

/// SYS-C13 Empty State — explains why there's nothing here and offers
/// one relevant next action.
class PsEmptyState extends StatelessWidget {
  const PsEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// A quieter second way out (e.g. "Browse categories" under "Clear search").
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    return PsCenteredScrollable(
      child: PsStateLayout(
        icon: icon,
        title: title,
        message: message,
        action: _actions(),
      ),
    );
  }

  Widget? _actions() {
    final primary = actionLabel != null && onAction != null
        ? PsPrimaryButton(label: actionLabel!, onPressed: onAction, uppercase: false, expand: false)
        : null;
    final secondary = secondaryActionLabel != null && onSecondaryAction != null
        ? PsSecondaryButton(label: secondaryActionLabel!, onPressed: onSecondaryAction)
        : null;
    if (primary == null || secondary == null) return primary ?? secondary;
    return Column(mainAxisSize: MainAxisSize.min, children: [primary, const SizedBox(height: 4), secondary]);
  }
}
