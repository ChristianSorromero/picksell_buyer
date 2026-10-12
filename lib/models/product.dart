import '../format_utils.dart';

/// A group of selectable options, e.g. Color: [Yellow, Black].
class ProductVariantGroup {
  const ProductVariantGroup({required this.name, required this.options});
  final String name;
  final List<String> options;
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    this.originalPrice,
    required this.sellerName,
    this.sellerLocation = '',
    this.isVerifiedSeller = true,
    this.rating = 0,
    this.soldCount = 0,
    required this.stock,
    this.description = '',
    this.images = const [],
    this.variantGroups = const [],
  });

  final int id;
  final String name;
  final String category;
  final double price;
  final double? originalPrice;
  final String sellerName;
  final String sellerLocation;
  final bool isVerifiedSeller;
  final double rating;
  final int soldCount;
  final int stock;
  final String description;
  final List<String> images;
  final List<ProductVariantGroup> variantGroups;

  bool get inStock => stock > 0;

  int? get discountPercent {
    final original = originalPrice;
    if (original == null || original <= price) return null;
    return (((original - price) / original) * 100).round();
  }

  String get soldLabel => '${compactCount(soldCount)} sold';

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as int,
      name: json['name'] as String,
      category: json['category'] as String? ?? '',
      price: (json['price'] as num).toDouble(),
      originalPrice: json['original_price'] != null
          ? (json['original_price'] as num).toDouble()
          : null,
      stock: json['stock'] as int,
      sellerName: json['seller_name'] as String? ?? '',
      sellerLocation: json['seller_location'] as String? ?? '',
      description: json['description'] as String? ?? '',
      images: json['images'] != null && (json['images'] as List).isNotEmpty
          ? List<String>.from(json['images'] as List)
          : json['primary_image'] != null ? [json['primary_image'] as String]
          : json['image'] != null ? [json['image'] as String] : [],
    );
  }
}
