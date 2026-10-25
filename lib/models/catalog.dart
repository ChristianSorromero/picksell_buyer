import 'json.dart';

class SellerBrief {
  const SellerBrief({required this.id, required this.name, this.location = '', this.verified = false});

  final int id;
  final String name;
  final String location;
  final bool verified;

  factory SellerBrief.fromJson(Json j) => SellerBrief(
        id: toInt(j['id']),
        name: j['name'] as String? ?? '',
        location: j['location'] as String? ?? '',
        verified: j['verified'] == true,
      );
}

/// COM-C04 data: seller identity + trust signals.
class SellerSummary extends SellerBrief {
  const SellerSummary({
    required super.id,
    required super.name,
    super.location,
    super.verified,
    this.rating,
    this.reviewCount = 0,
    this.positiveRate,
    this.productCount = 0,
    this.joinedAt,
  });

  final double? rating;
  final int reviewCount;
  final int? positiveRate;
  final int productCount;
  final DateTime? joinedAt;

  factory SellerSummary.fromJson(Json j) => SellerSummary(
        id: toInt(j['id']),
        name: j['name'] as String? ?? '',
        location: j['location'] as String? ?? '',
        verified: j['verified'] == true,
        rating: toDoubleOrNull(j['rating']),
        reviewCount: toInt(j['review_count']),
        positiveRate: j['positive_rate'] == null ? null : toInt(j['positive_rate']),
        productCount: toInt(j['product_count']),
        joinedAt: toDate(j['joined_at']),
      );
}

/// Card-sized product (COM-C01).
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.price,
    this.category = '',
    this.originalPrice,
    this.discountPercent,
    this.stock = 0,
    this.image,
    this.images = const [],
    this.rating,
    this.reviewCount = 0,
    this.soldCount = 0,
    this.isFeatured = false,
    this.isAvailable = true,
    this.wishlisted = false,
    this.seller,
  });

  final int id;
  final String name;
  final String category;
  final double price;
  final double? originalPrice;
  final int? discountPercent;
  final int stock;
  final String? image;
  final List<String> images;
  final double? rating;
  final int reviewCount;
  final int soldCount;
  final bool isFeatured;
  final bool isAvailable;
  final bool wishlisted;
  final SellerBrief? seller;

  bool get inStock => isAvailable && stock > 0;
  bool get onSale => discountPercent != null && discountPercent! > 0;
  bool get lowStock => inStock && stock <= 5;
  String get sellerName => seller?.name ?? '';

  factory Product.fromJson(Json j) {
    final seller = mapOrNull(j['seller']);
    return Product(
      id: toInt(j['id']),
      name: j['name'] as String? ?? '',
      category: j['category'] as String? ?? '',
      price: toDouble(j['price']),
      originalPrice: toDoubleOrNull(j['original_price']),
      discountPercent: j['discount_percent'] == null ? null : toInt(j['discount_percent']),
      stock: toInt(j['stock']),
      image: toStr(j['image']),
      images: (j['images'] as List?)?.map((e) => '$e').toList() ?? const [],
      rating: toDoubleOrNull(j['rating']),
      reviewCount: toInt(j['review_count']),
      soldCount: toInt(j['sold_count']),
      isFeatured: j['is_featured'] == true,
      isAvailable: j['is_available'] != false,
      wishlisted: j['wishlisted'] == true,
      seller: seller != null
          ? SellerBrief.fromJson(seller)
          : (j['seller_name'] != null ? SellerBrief(id: 0, name: '${j['seller_name']}', location: '${j['seller_location'] ?? ''}') : null),
    );
  }
}

class VariationOption {
  const VariationOption({required this.id, required this.value, required this.stock});

  final int id;
  final String value;
  final int stock;

  factory VariationOption.fromJson(Json j) =>
      VariationOption(id: toInt(j['id']), value: j['value'] as String? ?? '', stock: toInt(j['stock']));
}

/// A group of selectable options, e.g. Color: [Midnight Black, Arctic White].
class VariationGroup {
  const VariationGroup({required this.name, required this.options});

  final String name;
  final List<VariationOption> options;

  factory VariationGroup.fromJson(Json j) =>
      VariationGroup(name: j['name'] as String? ?? '', options: listOf(j['options'], VariationOption.fromJson));
}

class RatingSummary {
  const RatingSummary({this.average, this.count = 0, this.distribution = const {}});

  final double? average;
  final int count;

  /// star (1–5) → number of reviews.
  final Map<int, int> distribution;

  factory RatingSummary.fromJson(Json? j) {
    if (j == null) return const RatingSummary();
    final dist = <int, int>{};
    (mapOrNull(j['distribution']) ?? {}).forEach((k, v) => dist[toInt(k)] = toInt(v));
    return RatingSummary(average: toDoubleOrNull(j['average']), count: toInt(j['count']), distribution: dist);
  }
}

class Review {
  const Review({
    required this.id,
    required this.reviewer,
    required this.rating,
    this.comment,
    this.variationLabel,
    this.createdAt,
  });

  final int id;
  final String reviewer;
  final int rating;
  final String? comment;
  final String? variationLabel;
  final DateTime? createdAt;

  factory Review.fromJson(Json j) => Review(
        id: toInt(j['id']),
        reviewer: j['reviewer'] as String? ?? 'Picksell buyer',
        rating: toInt(j['rating']),
        comment: toStr(j['comment']),
        variationLabel: toStr(j['variation_label']),
        createdAt: toDate(j['created_at']),
      );
}

/// COM-C14 voucher offered on a product page, in the cart sheet or wallet.
class Voucher {
  const Voucher({
    required this.code,
    required this.title,
    required this.scope,
    this.type = 'fixed',
    this.value = 0,
    this.minSpend = 0,
    this.maxDiscount,
    this.isLimited = false,
    this.expiresAt,
    this.seller,
    this.eligible,
    this.discount,
  });

  final String code;
  final String title;

  /// platform | store
  final String scope;
  final String type;
  final double value;
  final double minSpend;
  final double? maxDiscount;
  final bool isLimited;
  final DateTime? expiresAt;
  final SellerBrief? seller;

  /// Only set when checked against selected cart items.
  final bool? eligible;
  final double? discount;

  factory Voucher.fromJson(Json j) => Voucher(
        code: j['code'] as String? ?? '',
        title: j['title'] as String? ?? '',
        scope: j['scope'] as String? ?? 'platform',
        type: j['type'] as String? ?? 'fixed',
        value: toDouble(j['value']),
        minSpend: toDouble(j['min_spend']),
        maxDiscount: toDoubleOrNull(j['max_discount']),
        isLimited: j['is_limited'] == true,
        expiresAt: toDate(j['expires_at']),
        seller: mapOrNull(j['seller']) == null ? null : SellerBrief.fromJson(mapOrNull(j['seller'])!),
        eligible: j['eligible'] as bool?,
        discount: toDoubleOrNull(j['discount']),
      );
}

/// COM-C15 shipping method with its delivery window.
class ShippingOption {
  const ShippingOption({
    required this.code,
    required this.name,
    required this.fee,
    this.minDays = 0,
    this.maxDays = 0,
    this.official = false,
    this.estimatedFrom,
    this.estimatedTo,
  });

  final String code;
  final String name;
  final double fee;
  final int minDays;
  final int maxDays;
  final bool official;
  final DateTime? estimatedFrom;
  final DateTime? estimatedTo;

  factory ShippingOption.fromJson(Json j) => ShippingOption(
        code: j['code'] as String? ?? 'standard',
        name: j['name'] as String? ?? '',
        fee: toDouble(j['fee']),
        minDays: toInt(j['min_days']),
        maxDays: toInt(j['max_days']),
        official: j['official'] == true,
        estimatedFrom: toDate(j['estimated_from']),
        estimatedTo: toDate(j['estimated_to']),
      );
}

class ProductDetail {
  const ProductDetail({
    required this.product,
    this.description = '',
    this.variationGroups = const [],
    this.maxQuantity = 1,
    this.seller,
    this.ratingSummary = const RatingSummary(),
    this.topReviews = const [],
    this.shipping,
    this.vouchers = const [],
  });

  final Product product;
  final String description;
  final List<VariationGroup> variationGroups;
  final int maxQuantity;
  final SellerSummary? seller;
  final RatingSummary ratingSummary;
  final List<Review> topReviews;
  final ShippingOption? shipping;
  final List<Voucher> vouchers;

  factory ProductDetail.fromJson(Json j) => ProductDetail(
        product: Product.fromJson(j),
        description: j['description'] as String? ?? '',
        variationGroups: listOf(j['variation_groups'], VariationGroup.fromJson),
        maxQuantity: toInt(j['max_quantity'], 1),
        seller: mapOrNull(j['seller']) == null ? null : SellerSummary.fromJson(mapOrNull(j['seller'])!),
        ratingSummary: RatingSummary.fromJson(mapOrNull(j['rating_summary'])),
        topReviews: listOf(j['top_reviews'], Review.fromJson),
        shipping: mapOrNull(j['shipping']) == null ? null : ShippingOption.fromJson(mapOrNull(j['shipping'])!),
        vouchers: listOf(j['vouchers'], Voucher.fromJson),
      );
}

class Category {
  const Category({required this.name, this.productCount = 0});

  final String name;
  final int productCount;

  factory Category.fromJson(Json j) => Category(name: j['name'] as String? ?? '', productCount: toInt(j['product_count']));
}

class HomeBanner {
  const HomeBanner({required this.kind, required this.title, this.subtitle, this.cta, this.image});

  /// deals | announcement
  final String kind;
  final String title;
  final String? subtitle;
  final String? cta;
  final String? image;

  factory HomeBanner.fromJson(Json j) => HomeBanner(
        kind: j['kind'] as String? ?? 'announcement',
        title: j['title'] as String? ?? '',
        subtitle: toStr(j['subtitle']),
        cta: toStr(j['cta']),
        image: toStr(j['image']),
      );
}

class HomeFeed {
  const HomeFeed({
    this.banners = const [],
    this.categories = const [],
    this.hotDiscounts = const [],
    this.featured = const [],
    this.recommended = const [],
  });

  final List<HomeBanner> banners;
  final List<Category> categories;
  final List<Product> hotDiscounts;
  final List<Product> featured;
  final List<Product> recommended;

  factory HomeFeed.fromJson(Json j) => HomeFeed(
        banners: listOf(j['banners'], HomeBanner.fromJson),
        categories: listOf(j['categories'], Category.fromJson),
        hotDiscounts: listOf(j['hot_discounts'], Product.fromJson),
        featured: listOf(j['featured'], Product.fromJson),
        recommended: listOf(j['recommended'], Product.fromJson),
      );
}

class PageMeta {
  const PageMeta({this.currentPage = 1, this.lastPage = 1, this.total = 0});

  final int currentPage;
  final int lastPage;
  final int total;

  bool get hasMore => currentPage < lastPage;

  factory PageMeta.fromJson(Json? j) => j == null
      ? const PageMeta()
      : PageMeta(currentPage: toInt(j['current_page'], 1), lastPage: toInt(j['last_page'], 1), total: toInt(j['total']));
}

class ProductPage {
  const ProductPage({required this.products, required this.meta});

  final List<Product> products;
  final PageMeta meta;
}

class ReviewPage {
  const ReviewPage({required this.summary, required this.reviews, required this.meta});

  final RatingSummary summary;
  final List<Review> reviews;
  final PageMeta meta;
}

class SellerStore {
  const SellerStore({required this.seller, this.categories = const [], this.products = const []});

  final SellerSummary seller;
  final List<String> categories;
  final List<Product> products;
}

/// Sort orders accepted by GET /products.
enum ProductSort {
  newest('newest', 'Newest'),
  popular('popular', 'Best selling'),
  rating('rating', 'Top rated'),
  priceAsc('price_asc', 'Price: Low to High'),
  priceDesc('price_desc', 'Price: High to Low');

  const ProductSort(this.apiValue, this.label);

  final String apiValue;
  final String label;
}
