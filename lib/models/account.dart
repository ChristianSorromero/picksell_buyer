import 'address.dart';
import 'json.dart';
import 'order.dart';

class BuyerProfile {
  const BuyerProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.contactNo,
    this.sex,
    this.birthday,
    this.memberSince,
  });

  final int id;
  final String firstName;
  final String lastName;
  final String email;

  /// Local format 09XXXXXXXXX.
  final String contactNo;
  final String? sex;
  final DateTime? birthday;
  final DateTime? memberSince;

  String get name => '$firstName $lastName'.trim();
  String get initials =>
      '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'.toUpperCase();

  factory BuyerProfile.fromJson(Json j) => BuyerProfile(
        id: toInt(j['id']),
        firstName: j['first_name'] as String? ?? '',
        lastName: j['last_name'] as String? ?? '',
        email: j['email'] as String? ?? '',
        contactNo: j['contact_no'] as String? ?? '',
        sex: toStr(j['sex']),
        birthday: toDate(j['birthday']),
        memberSince: toDate(j['member_since']),
      );
}

/// BUY-A01 + BUY-A02 payload.
class AccountOverview {
  const AccountOverview({
    required this.profile,
    this.orderCounts = const {},
    this.wishlistCount = 0,
    this.cartCount = 0,
    this.addressCount = 0,
    this.defaultAddress,
  });

  final BuyerProfile profile;
  final Map<OrderTab, int> orderCounts;
  final int wishlistCount;
  final int cartCount;
  final int addressCount;
  final Address? defaultAddress;

  factory AccountOverview.fromJson(Json j) {
    final stats = mapOrNull(j['stats']) ?? const {};
    return AccountOverview(
      profile: BuyerProfile.fromJson(mapOrNull(j['user']) ?? const {}),
      orderCounts: parseOrderCounts(mapOrNull(stats['order_counts'])),
      wishlistCount: toInt(stats['wishlist_count']),
      cartCount: toInt(stats['cart_count']),
      addressCount: toInt(stats['address_count']),
      defaultAddress: mapOrNull(j['default_address']) == null ? null : Address.fromJson(mapOrNull(j['default_address'])!),
    );
  }
}

/// BUY-A12 Notification Item.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.status,
    this.orderId,
    this.image,
    this.occurredAt,
    this.unread = false,
  });

  final String id;
  final String title;
  final String body;
  final String status;
  final int? orderId;
  final String? image;
  final DateTime? occurredAt;
  final bool unread;

  factory AppNotification.fromJson(Json j) => AppNotification(
        id: '${j['id']}',
        title: j['title'] as String? ?? '',
        body: j['body'] as String? ?? '',
        status: j['status'] as String? ?? '',
        orderId: j['order_id'] == null ? null : toInt(j['order_id']),
        image: toStr(j['image']),
        occurredAt: toDate(j['occurred_at']),
        unread: j['unread'] == true,
      );
}
