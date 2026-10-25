import 'package:flutter/material.dart';

import '../../../components/components.dart';
import '../../../format_utils.dart';
import '../../../models/account.dart';
import '../../../services/account_service.dart';
import '../nav.dart';

/// SYS-C16 Notification Center wired to order tracking events.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _account = AccountService();
  List<AppNotification> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await _account.notifications();
      if (!mounted) return;
      setState(() {
        _items = items;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAllRead() async {
    try {
      await _account.markAllRead();
      if (!mounted) return;
      setState(() => _items = [
            for (final n in _items)
              AppNotification(id: n.id, title: n.title, body: n.body, status: n.status, orderId: n.orderId, image: n.image, occurredAt: n.occurredAt),
          ]);
    } catch (e) {
      if (mounted) PsToast.error(context, errorMessage(e));
    }
  }

  static (IconData, Color) _style(String status) => switch (status) {
        'delivered' || 'completed' => (Icons.check_circle_rounded, PsColors.success),
        'cancelled' => (Icons.cancel_rounded, PsColors.textMuted),
        'delivery_failed' => (Icons.error_rounded, PsColors.error),
        'out_for_delivery' || 'assigned_to_rider' => (Icons.two_wheeler_rounded, PsColors.primary),
        'return_requested' || 'returned' => (Icons.undo_rounded, PsColors.warning),
        _ => (Icons.inventory_2_rounded, PsColors.info),
      };

  @override
  Widget build(BuildContext context) {
    final hasUnread = _items.any((n) => n.unread);
    return PsAppShell(
      topBar: PsTopBar(
        title: 'Notifications',
        actions: [if (hasUnread) TextButton(onPressed: _markAllRead, child: const Text('Mark all read'))],
      ),
      body: PsNotificationCenter(
        loading: _loading,
        errorMessage: _error,
        onRefresh: _load,
        entries: [
          for (final n in _items)
            PsNotificationEntry(
              id: n.id,
              icon: _style(n.status).$1,
              iconColor: _style(n.status).$2,
              title: n.title,
              body: n.body,
              timeLabel: n.occurredAt == null ? '' : formatRelative(n.occurredAt!),
              unread: n.unread,
              onTap: n.orderId == null ? null : () => openOrder(context, n.orderId!),
            ),
        ],
      ),
    );
  }
}
