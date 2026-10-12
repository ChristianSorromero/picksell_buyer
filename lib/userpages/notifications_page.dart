import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app_colors.dart';
import '../app_text_styles.dart';
import '../models/notification.dart';
import '../models/sample_notifications.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late List<AppNotification> _notifications;

  @override
  void initState() {
    super.initState();
    _notifications = List.of(sampleNotifications);
  }

  void _markAllRead() {
    setState(() {
      _notifications =
          _notifications.map((n) => n.copyWith(isUnread: false)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today =
        _notifications.where((n) => _isSameDay(n.timestamp, now)).toList();
    final earlier =
        _notifications.where((n) => !_isSameDay(n.timestamp, now)).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Notifications',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _notifications.any((n) => n.isUnread)
                ? _markAllRead
                : null,
            child: Text(
              'Mark all as read',
              style: AppTextStyles.link.copyWith(fontSize: 12.5),
            ),
          ),
        ],
      ),
      body: _notifications.isEmpty
          ? Center(
              child: Text('No notifications yet', style: AppTextStyles.body),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              children: [
                if (today.isNotEmpty) ..._buildSection('TODAY', today),
                if (earlier.isNotEmpty) ..._buildSection('EARLIER', earlier),
              ],
            ),
    );
  }

  List<Widget> _buildSection(String label, List<AppNotification> items) {
    return [
      Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 8),
        child: Text(label, style: AppTextStyles.caption),
      ),
      ...items.map((n) => _NotificationTile(notification: n)),
    ];
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    final style = notification.type;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: style.background,
              shape: BoxShape.circle,
            ),
            child: Icon(style.icon, size: 19, color: style.foreground),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  notification.body,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                timeAgoLabel(notification.timestamp),
                style: AppTextStyles.caption.copyWith(
                  fontSize: 10.5,
                  letterSpacing: 0,
                ),
              ),
              if (notification.isUnread) ...[
                const SizedBox(height: 6),
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
