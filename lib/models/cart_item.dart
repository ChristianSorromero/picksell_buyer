import 'product.dart';

/// A single line in the buyer's cart: a [product], how many, which variant,
/// and whether it's checked for checkout (grouped by seller in the UI).
class CartItem {
  CartItem({
    required this.product,
    this.quantity = 1,
    this.selectedVariant,
    this.isSelected = true,
  });

  final Product product;
  int quantity;

  /// e.g. "Brown Switch · Space Grey". Null if the product has no variants.
  String? selectedVariant;

  bool isSelected;

  double get lineTotal => product.price * quantity;
}
