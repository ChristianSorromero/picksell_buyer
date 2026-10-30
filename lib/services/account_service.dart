import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../models/account.dart';
import '../models/json.dart';

/// Profile (including the delivery address) and notifications for the
/// signed-in buyer.
class AccountService {
  AccountService({ApiClient? client}) : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  Future<AccountOverview> overview() async => AccountOverview.fromJson(await _api.getJson('/buyer/profile'));

  /// The website delivers every order to this address, so changing it here
  /// changes where new orders go.
  Future<BuyerProfile> updateProfile({
    required String firstName,
    required String lastName,
    required String birthday,
    required String contactNo,
    required String province,
    required String municipality,
    required String barangay,
    String? middleInitial,
    String? street,
    String? houseNo,
    String? sex,
  }) async {
    final j = await _api.patchJson('/buyer/profile', {
      'first_name': firstName,
      'last_name': lastName,
      'middle_initial': middleInitial,
      'birthday': birthday,
      'contact_no': contactNo,
      'sex': sex,
      'province': province,
      'municipality': municipality,
      'barangay': barangay,
      'street': street,
      'house_no': houseNo,
    });
    return BuyerProfile.fromJson(mapOrNull(j['user']) ?? const {});
  }

  Future<void> changePassword({required String current, required String password, required String confirmation}) =>
      _api.patchJson('/buyer/password', {
        'current_password': current,
        'password': password,
        'password_confirmation': confirmation,
      });

  // ── BUY-A12 Notifications ────────────────────────────────────────────────

  Future<List<AppNotification>> notifications() async {
    final j = await _api.getJson('/buyer/notifications');
    NotificationBadge.instance.value = toInt(j['unread_count']);
    return listOf(j['notifications'], AppNotification.fromJson);
  }

  Future<void> markAllRead() async {
    await _api.postJson('/buyer/notifications/read-all');
    NotificationBadge.instance.value = 0;
  }
}

/// Unread notification count for the bell icon.
class NotificationBadge extends ValueNotifier<int> {
  NotificationBadge._() : super(0);

  static final NotificationBadge instance = NotificationBadge._();
}
