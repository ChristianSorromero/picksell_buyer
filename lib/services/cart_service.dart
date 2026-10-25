import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../models/cart.dart';
import '../models/catalog.dart';
import '../models/json.dart';

/// API-C04 Cart Service. The server owns the cart; this store keeps the
/// latest priced snapshot and the badge count so every tab stays in sync.
class CartStore extends ChangeNotifier {
  CartStore({ApiClient? client}) : _api = client ?? ApiClient.instance;

  static CartStore instance = CartStore();

  final ApiClient _api;

  CartQuote _quote = const CartQuote();
  int _count = 0;

  CartQuote get quote => _quote;

  /// Units in the cart (bottom-nav badge).
  int get count => _count;

  void _apply(Json j) {
    _quote = CartQuote.fromJson(mapOrNull(j['cart']));
    _count = _quote.itemCount;
    notifyListeners();
  }

  Future<CartQuote> load() async {
    _apply(await _api.getJson('/buyer/cart'));
    return _quote;
  }

  /// Cheap badge refresh (no pricing).
  Future<void> refreshCount() async {
    try {
      _count = toInt((await _api.getJson('/buyer/cart/count'))['cart_count']);
      notifyListeners();
    } on ApiException {
      // Badge is best-effort; the cart screen shows real errors.
    }
  }

  /// COM-C10 Add-to-Cart. Returns the new cart line id (used by Buy Now).
  Future<int> add(Product product, {required int quantity, List<int> variationIds = const []}) async {
    final j = await _api.postJson('/buyer/cart', {
      'product_id': product.id,
      'quantity': quantity,
      'variation_ids': variationIds,
    });
    _count = toInt(j['cart_count'], _count + quantity);
    notifyListeners();
    return toInt(j['cart_item_id']);
  }

  Future<CartQuote> setQuantity(CartLine line, int quantity) async {
    _apply(await _api.patchJson('/buyer/cart/${line.id}', {'quantity': quantity}));
    return _quote;
  }

  Future<CartQuote> setVariations(CartLine line, List<int> variationIds) async {
    _apply(await _api.patchJson('/buyer/cart/${line.id}', {'variation_ids': variationIds}));
    return _quote;
  }

  Future<CartQuote> remove(CartLine line) async {
    _apply(await _api.deleteJson('/buyer/cart/${line.id}'));
    return _quote;
  }

  Future<CartQuote> removeMany(Iterable<int> lineIds) async {
    _apply(await _api.deleteJson('/buyer/cart', {'item_ids': lineIds.toList()}));
    return _quote;
  }

  /// Called after checkout so the badge reflects removed lines.
  void reset() {
    _quote = const CartQuote();
    _count = 0;
    notifyListeners();
    refreshCount();
  }
}
