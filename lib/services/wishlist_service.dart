import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../models/catalog.dart';
import '../models/json.dart';

/// COM-C07 / BUY-A05 "My Picks". Tracks saved product ids so every heart
/// button reflects the same state; toggles are optimistic and roll back on
/// failure.
class WishlistStore extends ChangeNotifier {
  WishlistStore({ApiClient? client}) : _api = client ?? ApiClient.instance;

  static WishlistStore instance = WishlistStore();

  final ApiClient _api;
  final Set<int> _ids = {};

  bool contains(int productId) => _ids.contains(productId);
  int get count => _ids.length;

  /// Seeds state from API payloads that already carry `wishlisted`.
  void sync(Iterable<Product> products) {
    var changed = false;
    for (final p in products) {
      changed |= p.wishlisted ? _ids.add(p.id) : _ids.remove(p.id);
    }
    if (changed) notifyListeners();
  }

  Future<List<Product>> load() async {
    final products = listOf((await _api.getJson('/buyer/wishlist'))['products'], Product.fromJson);
    _ids
      ..clear()
      ..addAll(products.map((p) => p.id));
    notifyListeners();
    return products;
  }

  /// Returns the new saved state; throws [ApiException] after rolling back.
  Future<bool> toggle(int productId) async {
    final saving = !_ids.contains(productId);
    saving ? _ids.add(productId) : _ids.remove(productId);
    notifyListeners();
    try {
      saving ? await _api.postJson('/buyer/wishlist/$productId') : await _api.deleteJson('/buyer/wishlist/$productId');
      return saving;
    } on ApiException {
      saving ? _ids.remove(productId) : _ids.add(productId);
      notifyListeners();
      rethrow;
    }
  }

  void clear() {
    _ids.clear();
    notifyListeners();
  }
}
