import '../core/network/api_client.dart';
import '../models/json.dart';

/// "Helpful" and Report on product reviews, as on the website's product page
/// (ReviewVotes, ReviewReports on the server).
class ReviewService {
  ReviewService({ApiClient? client}) : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  /// Mark ([helpful] true) or unmark; safe to repeat. Returns the new count.
  /// Throws [ApiException] 422 for your own review, 404 for a hidden one.
  Future<({bool helpful, int count})> setHelpful(int reviewId, {required bool helpful}) async {
    final path = '/buyer/reviews/$reviewId/helpful';
    final j = helpful ? await _api.postJson(path) : await _api.deleteJson(path);
    return (helpful: j['helpful'] == true, count: toInt(j['count']));
  }

  /// One report per buyer; reporting again replaces it. Returns the server's thank-you.
  Future<String> report(int reviewId, {required String reason, String? details}) async {
    final j = await _api.postJson('/buyer/reviews/$reviewId/report', {
      'reason': reason,
      if (details != null && details.trim().isNotEmpty) 'details': details.trim(),
    });
    return j['message'] as String? ?? 'Thanks. Our team will look at this review.';
  }
}
