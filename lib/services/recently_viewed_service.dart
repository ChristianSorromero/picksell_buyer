import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// BUY-A06 Recently Viewed — product ids kept on-device, newest first.
/// Screens re-fetch product cards so prices and stock are always current.
class RecentlyViewed {
  RecentlyViewed._();

  static const _key = 'recently_viewed_products';
  static const int limit = 20;

  static Future<List<int>> ids() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return [];
      return (jsonDecode(raw) as List).map((e) => (e as num).toInt()).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> add(int productId) async {
    final list = await ids()
      ..remove(productId)
      ..insert(0, productId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(list.take(limit).toList()));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
