import 'package:flutter/material.dart';

import '../../../components/components.dart';
import '../../../format_utils.dart';
import '../../../models/account.dart';
import '../nav.dart';

/// One notification in full: the list shortens long titles and messages.
class NotificationDetailPage extends StatelessWidget {
  const NotificationDetailPage({super.key, required this.notification, required this.icon, required this.iconColor});

  final AppNotification notification;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final n = notification;
    return PsAppShell(
      topBar: const PsTopBar(title: 'Notification'),
      footer: n.orderId == null
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(PsSpace.gutter, PsSpace.sm, PsSpace.gutter, PsSpace.sm),
                child: PsPrimaryButton(label: 'View order', uppercase: false, onPressed: () => openOrder(context, n.orderId!)),
              ),
            ),
      body: ListView(
        padding: const EdgeInsets.all(PsSpace.gutter),
        children: [
          PsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: iconColor.withAlpha(30), shape: BoxShape.circle),
                      child: Icon(icon, color: iconColor, size: 22),
                    ),
                    const SizedBox(width: PsSpace.sm),
                    Expanded(
                      child: Text(n.occurredAt == null ? '' : formatDateTime(n.occurredAt!.toLocal()), style: PsText.caption),
                    ),
                  ],
                ),
                const SizedBox(height: PsSpace.md),
                SelectableText(n.title, style: PsText.heading),
                if (n.body.isNotEmpty) ...[
                  const SizedBox(height: PsSpace.xs),
                  SelectableText(n.body, style: PsText.body),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
