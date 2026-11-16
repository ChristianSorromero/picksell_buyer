import 'dart:typed_data';

import '../core/network/api_client.dart';
import '../models/json.dart';
import '../models/order.dart';

/// API-C06 Order Service + returns, reports and reorder.
class OrderService {
  OrderService({ApiClient? client}) : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  /// The rider's photo at the door, when [OrderDetail.hasProofOfDelivery]. Private: downloaded with the buyer's login.
  Future<Uint8List> proofOfDelivery(int orderId) => _api.getBytes('/buyer/orders/$orderId/proof-of-delivery');

  /// The Pickrush 4×6 return label (PDF) of an approved return.
  Future<Uint8List> returnWaybill(int orderId) => _api.getBytes('/buyer/orders/$orderId/return/waybill');

  Future<OrderList> list({OrderTab tab = OrderTab.all}) async {
    final j = await _api.getJson('/buyer/orders', query: {'tab': tab.apiValue});
    return OrderList(orders: listOf(j['orders'], OrderSummaryItem.fromJson), counts: parseOrderCounts(mapOrNull(j['counts'])));
  }

  Future<OrderDetail> detail(int id) async => _detail(await _api.getJson('/buyer/orders/$id'));

  OrderDetail _detail(Json j) => OrderDetail.fromJson(mapOrNull(j['order']) ?? const {});

  Future<OrderOptions> options() async => OrderOptions.fromJson(await _api.getJson('/buyer/orders/options'));

  /// "Order Received": the delivered parcel reached the buyer. Completes the order; then it can be rated.
  Future<OrderDetail> confirmReceived(int id) async => _detail(await _api.postJson('/buyer/orders/$id/received'));

  Future<OrderDetail> cancel(int id, String reason) async =>
      _detail(await _api.postJson('/buyer/orders/$id/cancel', {'reason': reason}));

  /// The website's order rating: the product, the seller's service and the delivery (all 1–5),
  /// an optional comment and up to 3 photos, once the buyer confirmed receipt. The product stars
  /// are published as the product review straight away.
  Future<OrderDetail> rate(
    int id, {
    required int rating,
    required int sellerRating,
    required int deliveryRating,
    String? feedback,
    List<String> photos = const [],
  }) async =>
      _detail(await _api.multipartJson(
        '/buyer/orders/$id/rate',
        fields: {
          'rating': '$rating',
          'seller_rating': '$sellerRating',
          'delivery_rating': '$deliveryRating',
          if (feedback != null && feedback.trim().isNotEmpty) 'feedback': feedback.trim(),
        },
        files: {if (photos.isNotEmpty) 'photos': photos},
      ));

  /// Returns the ticket reference, e.g. TKT-000012.
  /// A problem with the courier (late, not received, damaged, rider conduct):
  /// goes to the logistics company carrying the parcel. One photo, as on the website.
  Future<String> reportDeliveryProblem(int id, {required String type, required String description, String? photo}) async {
    final j = await _api.multipartJson(
      '/buyer/orders/$id/delivery-problem',
      fields: {'type': type, 'description': description},
      singleFiles: {'evidence': ?photo},
    );
    return '${j['message'] ?? ''}';
  }

  /// The seller asked to pay, chat or ship outside PickSell: PickSell reviews
  /// the seller (who isn't told who reported). Returns the server's thank-you.
  Future<String> reportOffPlatform(int id, {required String details}) async {
    final j = await _api.postJson('/buyer/orders/$id/report-off-platform', {'details': details});
    return '${j['message'] ?? ''}';
  }

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
    int? orderItemId,
    required String reason,
    required String details,
    required String gcashNumber,
    required String gcashName,
    List<String> photos = const [],
  }) async {
    final j = await _api.multipartJson(
      '/buyer/orders/$id/return',
      fields: {
        'quantity': '$quantity',
        'reason': reason,
        'details': details.trim(),
        // Where PickSell sends the refund.
        'gcash_number': gcashNumber.trim(),
        'gcash_name': gcashName.trim(),
      },
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
