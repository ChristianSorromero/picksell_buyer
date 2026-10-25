import '../core/network/api_client.dart';
import '../models/catalog.dart';
import '../models/json.dart';

/// API-C03 Product Service — public catalog.
class CatalogService {
  CatalogService({ApiClient? client}) : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  Future<HomeFeed> home() async => HomeFeed.fromJson(await _api.getJson('/home'));

  Future<List<Category>> categories() async =>
      listOf((await _api.getJson('/categories'))['categories'], Category.fromJson);

  Future<ProductPage> products({
    String? search,
    String? category,
    ProductSort sort = ProductSort.newest,
    bool onSale = false,
    double? minPrice,
    double? maxPrice,
    int? sellerId,
    int page = 1,
  }) async {
    final j = await _api.getJson('/products', query: {
      if (search != null && search.isNotEmpty) 'search': search,
      if (category != null && category.isNotEmpty) 'category': category,
      'sort': sort.apiValue,
      if (onSale) 'on_sale': 1,
      'min_price': minPrice,
      'max_price': maxPrice,
      'seller_id': sellerId,
      'page': page,
    });
    return ProductPage(products: listOf(j['products'], Product.fromJson), meta: PageMeta.fromJson(mapOrNull(j['meta'])));
  }

  Future<ProductDetail> product(int id) async =>
      ProductDetail.fromJson(mapOrNull((await _api.getJson('/products/$id'))['product']) ?? const {});

  Future<ReviewPage> reviews(int productId, {int? rating, bool withComments = false, int page = 1}) async {
    final j = await _api.getJson('/products/$productId/reviews', query: {
      'rating': rating,
      if (withComments) 'with_comments': 1,
      'page': page,
    });
    return ReviewPage(
      summary: RatingSummary.fromJson(mapOrNull(j['summary'])),
      reviews: listOf(j['reviews'], Review.fromJson),
      meta: PageMeta.fromJson(mapOrNull(j['meta'])),
    );
  }

  Future<SellerStore> seller(int id) async {
    final j = await _api.getJson('/sellers/$id');
    return SellerStore(
      seller: SellerSummary.fromJson(mapOrNull(j['seller']) ?? const {}),
      categories: (j['categories'] as List?)?.map((e) => '$e').toList() ?? const [],
      products: listOf(j['products'], Product.fromJson),
    );
  }

  /// Typeahead from GET /search-suggestions.
  Future<({List<String> products, List<String> categories})> suggestions(String query) async {
    final j = await _api.getJson('/search-suggestions', query: {'q': query});
    return (
      products: listOf(j['products'], (p) => '${p['name']}'),
      categories: (j['categories'] as List?)?.map((e) => '$e').toList() ?? const <String>[],
    );
  }

  Future<List<ShippingOption>> shippingOptions() async =>
      listOf((await _api.getJson('/shipping-options'))['shipping_options'], ShippingOption.fromJson);
}
