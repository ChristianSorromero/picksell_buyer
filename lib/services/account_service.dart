import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../models/account.dart';
import '../models/address.dart';
import '../models/json.dart';

/// Profile, address book and notifications for the signed-in buyer.
class AccountService {
  AccountService({ApiClient? client}) : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  Future<AccountOverview> overview() async => AccountOverview.fromJson(await _api.getJson('/buyer/profile'));

  Future<BuyerProfile> updateProfile({
    required String firstName,
    required String lastName,
    required String birthday,
    required String contactNo,
    String? sex,
  }) async {
    final j = await _api.patchJson('/buyer/profile', {
      'first_name': firstName,
      'last_name': lastName,
      'birthday': birthday,
      'contact_no': contactNo,
      'sex': sex,
    });
    return BuyerProfile.fromJson(mapOrNull(j['user']) ?? const {});
  }

  Future<void> changePassword({required String current, required String password, required String confirmation}) =>
      _api.patchJson('/buyer/password', {
        'current_password': current,
        'password': password,
        'password_confirmation': confirmation,
      });

  // ── BUY-A03 Address Manager ──────────────────────────────────────────────

  Future<List<Address>> addresses() async =>
      listOf((await _api.getJson('/buyer/addresses'))['addresses'], Address.fromJson);

  Future<Address> saveAddress(Address address, {int? id}) async {
    final j = id == null
        ? await _api.postJson('/buyer/addresses', address.toJson())
        : await _api.patchJson('/buyer/addresses/$id', address.toJson());
    return Address.fromJson(mapOrNull(j['address']) ?? const {});
  }

  Future<Address> makeDefault(int id) async =>
      Address.fromJson(mapOrNull((await _api.patchJson('/buyer/addresses/$id', {'is_default': true}))['address']) ?? const {});

  Future<List<Address>> deleteAddress(int id) async =>
      listOf((await _api.deleteJson('/buyer/addresses/$id'))['addresses'], Address.fromJson);

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
