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
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return PsCenteredScrollable(
      child: PsStateLayout(
        icon: icon,
        title: title,
        message: message,
        action: actionLabel != null && onAction != null
            ? PsPrimaryButton(label: actionLabel!, onPressed: onAction, uppercase: false, expand: false)
            : null,
      ),
    );
  }
}
