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

  Future<ReturnRequest> requestReturn(
    int id, {
    required int quantity,
    required String reason,
    required String refundTo,
    String? details,
    List<String> photos = const [],
  }) async {
    final j = await _api.multipartJson(
      '/buyer/orders/$id/return',
      fields: {
        'quantity': '$quantity',
        'reason': reason,
        'refund_to': refundTo,
        if (details != null && details.trim().isNotEmpty) 'details': details.trim(),
      },
      files: {if (photos.isNotEmpty) 'evidence': photos},
    );
    return ReturnRequest.fromJson(mapOrNull(j['return_request']) ?? const {});
  }

  /// Answers Picksell's request for more information on a return.
  Future<ReturnRequest> replyToReturn(int returnId, {required String details, List<String> photos = const []}) async {
    final j = await _api.multipartJson(
      '/buyer/returns/$returnId/reply',
      fields: {'details': details.trim()},
      files: {if (photos.isNotEmpty) 'evidence': photos},
    );
    return ReturnRequest.fromJson(mapOrNull(j['return_request']) ?? const {});
  }

  Future<ReturnRequest> acceptReturnProposal(int returnId) async =>
      ReturnRequest.fromJson(mapOrNull((await _api.postJson('/buyer/returns/$returnId/accept'))['return_request']) ?? const {});

  /// Declining sends the case to Picksell for a final decision.
  Future<ReturnRequest> declineReturnProposal(int returnId, {required String reason}) async => ReturnRequest.fromJson(
      mapOrNull((await _api.postJson('/buyer/returns/$returnId/decline', {'reason': reason.trim()}))['return_request']) ?? const {});

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
