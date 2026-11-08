import '../core/network/api_client.dart';
import '../models/catalog.dart';
import '../models/json.dart';

/// A store the buyer follows (website: Following page).
class FollowedStore extends SellerBrief {
  const FollowedStore({
    required super.id,
    required super.name,
    super.location,
    super.verified,
    super.onVacation,
    this.logo,
    this.activeProducts = 0,
    this.followedAt,
  });

  final String? logo;
  final int activeProducts;
  final DateTime? followedAt;

  factory FollowedStore.fromJson(Json j) => FollowedStore(
        id: toInt(j['id']),
        name: j['name'] as String? ?? '',
        location: j['location'] as String? ?? '',
        verified: j['verified'] == true,
        onVacation: j['on_vacation'] == true,
        logo: toStr(j['logo']),
        activeProducts: toInt(j['active_products']),
        followedAt: toDate(j['followed_at']),
      );
}

/// After a follow or unfollow: the server's answer.
class FollowState {
  const FollowState({required this.following, required this.followers});

  final bool following;
  final int followers;

  factory FollowState.fromJson(Json j) => FollowState(following: j['following'] == true, followers: toInt(j['followers']));
}

/// Following stores, as on the website (SellerFollows on the server).
class FollowService {
  FollowService({ApiClient? client}) : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  Future<({List<FollowedStore> stores, PageMeta meta})> following({int page = 1}) async {
    final j = await _api.getJson('/buyer/following', query: {'page': page});
    return (stores: listOf(j['stores'], FollowedStore.fromJson), meta: PageMeta.fromJson(mapOrNull(j['meta'])));
  }

  /// Follow ([follow] true) or unfollow; safe to repeat.
  Future<FollowState> set(int sellerId, {required bool follow}) async {
    final path = '/buyer/sellers/$sellerId/follow';
    return FollowState.fromJson(follow ? await _api.postJson(path) : await _api.deleteJson(path));
  }
}
