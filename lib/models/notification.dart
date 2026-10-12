import 'package:flutter/material.dart';

import '../app_colors.dart';

/// Kinds of notification shown on [NotificationsPage]. Add new values here
/// and give them an icon/color pair below as the backend grows the list.
enum NotificationType {
  flashSale,
  orderShipped,
  newMessage,
  priceDrop,
  orderDelivered,
}

extension NotificationTypeStyle on NotificationType {
  IconData get icon {
    switch (this) {
      case NotificationType.flashSale:
        return Icons.local_offer_rounded;
      case NotificationType.orderShipped:
        return Icons.inventory_2_rounded;
      case NotificationType.newMessage:
        return Icons.chat_bubble_rounded;
      case NotificationType.priceDrop:
        return Icons.favorite_rounded;
      case NotificationType.orderDelivered:
        return Icons.check_circle_rounded;
    }
  }

  Color get foreground {
    switch (this) {
      case NotificationType.flashSale:
      case NotificationType.priceDrop:
        return AppColors.primary;
      case NotificationType.orderShipped:
      case NotificationType.orderDelivered:
        return AppColors.verified;
      case NotificationType.newMessage:
        return AppColors.success;
    }
  }

  /// Light tint of [foreground] for the icon's circular badge background.
  Color get background => foreground.withAlpha(28);
}

/// A single entry in the notifications list.
///
/// Right now notifications are hardcoded in `sample_notifications.dart`.
/// When the backend exposes a notifications endpoint, map the API response
/// into this class the same way `Product` is mapped from product JSON.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.timestamp,
    this.isUnread = false,
  });

  final int id;
  final NotificationType type;
  final String title;
  final String body;
  final DateTime timestamp;
  final bool isUnread;

  AppNotification copyWith({bool? isUnread}) {
    return AppNotification(
      id: id,
      type: type,
      title: title,
      body: body,
      timestamp: timestamp,
      isUnread: isUnread ?? this.isUnread,
    );
  }
}

/// Formats a timestamp the way the design shows it:
/// 2m ago / 1h ago / Yesterday / 3 days ago / Oct 24
String timeAgoLabel(DateTime dateTime) {
  final now = DateTime.now();
  final diff = now.difference(dateTime);

  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (_isSameDay(dateTime, now)) return '${diff.inHours}h ago';

  final yesterday = now.subtract(const Duration(days: 1));
  if (_isSameDay(dateTime, yesterday)) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays} days ago';

  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[dateTime.month - 1]} ${dateTime.day}';
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
