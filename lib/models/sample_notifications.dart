import 'notification.dart';

/// Hardcoded for now — same pattern as `sample_products.dart`. When the
/// backend exposes a notifications endpoint, replace this with the mapped
/// API response.
final List<AppNotification> sampleNotifications = [
  AppNotification(
    id: 1,
    type: NotificationType.flashSale,
    title: 'Flash Sale Alert! ⚡',
    body: 'Get up to 70% off on electronics for the next 2 hours. '
        "Don't miss out!",
    timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
    isUnread: true,
  ),
  AppNotification(
    id: 2,
    type: NotificationType.orderShipped,
    title: 'Order Shipped',
    body: 'Your order #PS-9421 has been picked up by the courier and is '
        'on its way.',
    timestamp: DateTime.now().subtract(const Duration(hours: 1)),
    isUnread: true,
  ),
  AppNotification(
    id: 3,
    type: NotificationType.newMessage,
    title: 'New Message',
    body: 'Sarah Jenkins sent you a message about the vintage camera.',
    timestamp: DateTime.now().subtract(const Duration(days: 1)),
  ),
  AppNotification(
    id: 4,
    type: NotificationType.priceDrop,
    title: 'Price Drop',
    body: 'An item in your wishlist "Mechanical Keyboard" is now 15% off.',
    timestamp: DateTime.now().subtract(const Duration(days: 2)),
  ),
  AppNotification(
    id: 5,
    type: NotificationType.orderDelivered,
    title: 'Order Delivered',
    body: 'Great news! Your order #PS-8820 was delivered successfully. '
        'Rate your experience.',
    timestamp: DateTime.now().subtract(const Duration(days: 11)),
  ),
];
