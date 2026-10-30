import '../core/network/api_client.dart';
import '../models/json.dart';
import '../models/order.dart';

/// API-C06 Order Service + returns, reports and reorder.
class OrderService {
  OrderService({ApiClient? client}) : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  Future<OrderList> list({OrderTab tab = OrderTab.all}) async {
    final j = await _api.getJson('/buyer/orders', query: {'tab': tab.apiValue});
    return OrderList(orders: listOf(j['orders'], OrderSummaryItem.fromJson), counts: parseOrderCounts(mapOrNull(j['counts'])));
  }

  Future<OrderDetail> detail(int id) async => _detail(await _api.getJson('/buyer/orders/$id'));

  OrderDetail _detail(Json j) => OrderDetail.fromJson(mapOrNull(j['order']) ?? const {});

  Future<OrderOptions> options() async => OrderOptions.fromJson(await _api.getJson('/buyer/orders/options'));

  Future<OrderDetail> cancel(int id, String reason) async =>
      _detail(await _api.postJson('/buyer/orders/$id/cancel', {'reason': reason}));

  Future<OrderDetail> rate(int id, {required int rating, String? feedback}) async => _detail(await _api.postJson(
        '/buyer/orders/$id/rate',
        {'rating': rating, if (feedback != null && feedback.trim().isNotEmpty) 'feedback': feedback.trim()},
      ));

  /// Returns the ticket reference, e.g. TKT-000012.
  Future<String> report(int id, {required String category, required String details, List<String> photos = const []}) async {
    final j = await _api.multipartJson(
      '/buyer/orders/$id/report',
      fields: {'category': category, 'details': details},
      files: {if (photos.isNotEmpty) 'evidence': photos},
    );
    return '${mapOrNull(j['ticket'])?['reference'] ?? ''}';
  }

  /// The website's return request: the seller reviews it first; if they
  /// decline, PickSell support reviews it. Up to 5 photos or videos.
  Future<ReturnRequest> requestReturn(
    int id, {
    required int quantity,
    required String reason,
    required String details,
    List<String> photos = const [],
  }) async {
    final j = await _api.multipartJson(
      '/buyer/orders/$id/return',
      fields: {'quantity': '$quantity', 'reason': reason, 'details': details.trim()},
      files: {if (photos.isNotEmpty) 'evidence': photos},
    );
    return ReturnRequest.fromJson(mapOrNull(j['return_request']) ?? const {});
  }

  /// Adds the order's product back to the cart at today's price.
  Future<({String message, bool priceChanged})> reorder(int id) async {
    final j = await _api.postJson('/buyer/orders/$id/reorder');
    return (message: '${j['message']}', priceChanged: j['price_changed'] == true);
  }

  Future<List<ReorderItem>> reorderCandidates() async =>
      listOf((await _api.getJson('/buyer/reorder'))['items'], ReorderItem.fromJson);

  Future<List<SupportTicket>> tickets() async =>
      listOf((await _api.getJson('/buyer/support/tickets'))['tickets'], SupportTicket.fromJson);
}
