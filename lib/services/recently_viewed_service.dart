import '../core/network/api_client.dart';
import '../models/catalog.dart';
import '../models/json.dart';

/// BUY-A06 Recently Viewed — kept on the server and shared with the
/// website's "Recently Viewed" row. The server adds a product whenever a
/// signed-in buyer opens it, so there is nothing to record here.
class RecentlyViewedService {
  RecentlyViewedService({ApiClient? client}) : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  /// Newest first; only products that can still be bought.
  Future<List<Product>> list() async => listOf((await _api.getJson('/buyer/recently-viewed'))['products'], Product.fromJson);

  /// Clears the history on the website too.
  Future<void> clear() async => _api.deleteJson('/buyer/recently-viewed');
}
