import 'package:flutter/foundation.dart';

import '../models/cart_item.dart';
import '../models/product.dart';

/// In-memory cart state shared across the app.
///
/// This is a plain [ChangeNotifier] singleton so it works without adding a
/// state-management package. Widgets that need to rebuild on cart changes
/// should wrap themselves in an `AnimatedBuilder(animation: CartService.instance, ...)`
/// or `ListenableBuilder`.
///
/// When orders/cart are wired up to the backend, this class is the one place
/// to swap in real persistence (an API call in each method instead of the
/// in-memory list).
class CartService extends ChangeNotifier {
  CartService._();

  static final CartService instance = CartService._();

  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);

  bool get isEmpty => _items.isEmpty;

  /// Total number of units across all items (used for the cart badge).
  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  /// Items grouped by seller, in the order sellers first appeared.
  Map<String, List<CartItem>> get groupedBySeller {
    final map = <String, List<CartItem>>{};
    for (final item in _items) {
      map.putIfAbsent(item.product.sellerName, () => []).add(item);
    }
    return map;
  }

  void addProduct(Product product, int quantity, {String? variant}) {
    final index = _items.indexWhere(
      (item) =>
          item.product.id == product.id && item.selectedVariant == variant,
    );
    if (index != -1) {
      _items[index].quantity += quantity;
    } else {
      _items.add(
        CartItem(product: product, quantity: quantity, selectedVariant: variant),
      );
    }
    notifyListeners();
  }

  void removeItem(CartItem item) {
    _items.remove(item);
    notifyListeners();
  }

  void updateQuantity(CartItem item, int quantity) {
    if (quantity <= 0) {
      removeItem(item);
      return;
    }
    item.quantity = quantity;
    notifyListeners();
  }

  void toggleSelected(CartItem item, bool value) {
    item.isSelected = value;
    notifyListeners();
  }

  void toggleSeller(String sellerName, bool value) {
    for (final item in _items) {
      if (item.product.sellerName == sellerName) item.isSelected = value;
    }
    notifyListeners();
  }

  bool isSellerFullySelected(String sellerName) {
    final sellerItems =
        _items.where((item) => item.product.sellerName == sellerName);
    if (sellerItems.isEmpty) return false;
    return sellerItems.every((item) => item.isSelected);
  }

  double get selectedSubtotal => _items
      .where((item) => item.isSelected)
      .fold(0.0, (sum, item) => sum + item.lineTotal);

  int get selectedCount => _items
      .where((item) => item.isSelected)
      .fold(0, (sum, item) => sum + item.quantity);

  void clear() {
    _items.clear();
    notifyListeners();
  }
}
