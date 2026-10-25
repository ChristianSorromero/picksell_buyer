import '../core/status/order_status.dart';
import 'address.dart';
import 'catalog.dart';
import 'json.dart';

/// Tabs on "My Orders", matching App\Support\OrderStatus::TABS.
enum OrderTab {
  all('all', 'All'),
  toShip('to_ship', 'To Ship'),
  inTransit('in_transit', 'In Transit'),
  outForDelivery('out_for_delivery', 'Out for Delivery'),
  toRate('to_rate', 'To Rate'),
  completed('completed', 'Completed'),
  cancelled('cancelled', 'Cancelled');

  const OrderTab(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static OrderTab fromApi(Object? v) => values.firstWhere((t) => t.apiValue == v, orElse: () => toShip);
}

/// COM-C20 Order Card.
class OrderSummaryItem {
  const OrderSummaryItem({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.tab,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.total,
    this.checkoutRef,
    this.seller,
    this.productId,
    this.image,
    this.variationLabel,
    this.rating,
    this.createdAt,
  });

  final int id;
  final String orderNumber;
  final String? checkoutRef;
  final OrderStatus status;
  final OrderTab tab;
  final SellerBrief? seller;
  final int? productId;
  final String productName;
  final String? image;
  final String? variationLabel;
  final int quantity;
  final double unitPrice;
  final double total;
  final int? rating;
  final DateTime? createdAt;

  factory OrderSummaryItem.fromJson(Json j) => OrderSummaryItem(
        id: toInt(j['id']),
        orderNumber: j['order_number'] as String? ?? '',
        checkoutRef: toStr(j['checkout_ref']),
        status: OrderStatus.fromApi(j['status'] as String?),
        tab: OrderTab.fromApi(j['tab']),
        seller: mapOrNull(j['seller']) == null ? null : SellerBrief.fromJson(mapOrNull(j['seller'])!),
        productId: j['product_id'] == null ? null : toInt(j['product_id']),
        productName: j['product_name'] as String? ?? '',
        image: toStr(j['image']),
        variationLabel: toStr(j['variation_label']),
        quantity: toInt(j['quantity'], 1),
        unitPrice: toDouble(j['unit_price']),
        total: toDouble(j['total']),
        rating: j['rating'] == null ? null : toInt(j['rating']),
        createdAt: toDate(j['created_at']),
      );
}

/// LOG-C02 Tracking Event.
class TrackingEvent {
  const TrackingEvent({required this.status, required this.title, this.description, this.location, this.occurredAt});

  /// Raw API value (may be outside [OrderStatus], e.g. return_requested).
  final String status;
  final String title;
  final String? description;
  final String? location;
  final DateTime? occurredAt;

  factory TrackingEvent.fromJson(Json j) => TrackingEvent(
        status: j['status'] as String? ?? '',
        title: j['title'] as String? ?? '',
        description: toStr(j['description']),
        location: toStr(j['location']),
        occurredAt: toDate(j['occurred_at']),
      );
}

class CourierInfo {
  const CourierInfo({required this.name, this.vehicle, this.phone});

  final String name;
  final String? vehicle;

  /// Only present while the rider is actively assigned to this order.
  final String? phone;

  factory CourierInfo.fromJson(Json j) =>
      CourierInfo(name: j['name'] as String? ?? '', vehicle: toStr(j['vehicle']), phone: toStr(j['phone']));
}

/// Frozen delivery address on the order.
class ShipTo {
  const ShipTo({required this.recipientName, required this.phone, required this.fullAddress, this.label, this.landmark});

  final String recipientName;
  final String phone;
  final String fullAddress;
  final AddressLabel? label;
  final String? landmark;

  String get displayPhone => formatPhPhone(phone);

  factory ShipTo.fromJson(Json j) => ShipTo(
        recipientName: j['recipient_name'] as String? ?? '',
        phone: j['phone'] as String? ?? '',
        fullAddress: j['full_address'] as String? ?? '',
        label: j['label'] == null ? null : AddressLabel.fromApi(j['label']),
        landmark: toStr(j['landmark']),
      );
}

enum RefundStage { requested, underReview, processing, refunded, rejected }

/// BUY-C11/C12.
class ReturnRequest {
  const ReturnRequest({
    required this.id,
    required this.stage,
    required this.quantity,
    required this.reason,
    required this.refundAmount,
    required this.refundTo,
    this.details,
    this.evidence = const [],
    this.requestedAt,
    this.reviewedAt,
    this.processingAt,
    this.refundedAt,
    this.rejectedAt,
    this.resolutionNote,
    this.stageLabel,
    this.awaiting,
    this.infoRequest,
    this.proposal,
  });

  final int id;
  final RefundStage stage;

  /// Detailed step, e.g. "Seller proposed a resolution".
  final String? stageLabel;

  /// What the buyer has to do next: 'reply' (admin asked a question) or
  /// 'decide' (accept or decline the seller's proposal).
  final String? awaiting;
  final String? infoRequest;
  final ReturnProposal? proposal;
  final int quantity;
  final String reason;
  final String? details;
  /// What the buyer asked for until a resolution is agreed; the agreed
  /// amount afterwards (see [isAgreed]).
  final double refundAmount;
  final String refundTo;
  final List<String> evidence;

  bool get isAgreed => stage == RefundStage.processing || stage == RefundStage.refunded;
  final DateTime? requestedAt;
  final DateTime? reviewedAt;
  final DateTime? processingAt;
  final DateTime? refundedAt;
  final DateTime? rejectedAt;
  final String? resolutionNote;

  factory ReturnRequest.fromJson(Json j) => ReturnRequest(
        id: toInt(j['id']),
        stage: switch (j['status']) {
          'under_review' => RefundStage.underReview,
          'processing' => RefundStage.processing,
          'refunded' => RefundStage.refunded,
          'rejected' => RefundStage.rejected,
          _ => RefundStage.requested,
        },
        quantity: toInt(j['quantity'], 1),
        reason: j['reason'] as String? ?? '',
        details: toStr(j['details']),
        refundAmount: toDouble(j['refund_amount']),
        refundTo: j['refund_to'] as String? ?? '',
        evidence: (j['evidence'] as List?)?.map((e) => '$e').toList() ?? const [],
        requestedAt: toDate(j['requested_at']),
        reviewedAt: toDate(j['reviewed_at']),
        processingAt: toDate(j['processing_at']),
        refundedAt: toDate(j['refunded_at']),
        rejectedAt: toDate(j['rejected_at']),
        resolutionNote: toStr(j['resolution_note']),
        stageLabel: toStr(j['stage_label']),
        awaiting: toStr(j['awaiting']),
        infoRequest: toStr(j['info_request']),
        proposal: j['proposal'] is Map ? ReturnProposal.fromJson((j['proposal'] as Map).cast<String, dynamic>()) : null,
      );
}

/// The seller's proposed resolution, waiting for the buyer.
class ReturnProposal {
  const ReturnProposal({required this.label, required this.amount, required this.itemMustReturn, this.note});

  final String label;
  final double amount;
  final bool itemMustReturn;
  final String? note;

  factory ReturnProposal.fromJson(Json j) => ReturnProposal(
        label: j['label'] as String? ?? '',
        amount: toDouble(j['amount']),
        itemMustReturn: j['item_must_return'] == true,
        note: toStr(j['note']),
      );
}

/// BUY-C14 — which actions the backend allows right now.
class OrderActions {
  const OrderActions({
    this.canCancel = false,
    this.canRate = false,
    this.canReturn = false,
    this.canReport = false,
    this.canReorder = false,
    this.canTrack = false,
  });

  final bool canCancel;
  final bool canRate;
  final bool canReturn;
  final bool canReport;
  final bool canReorder;
  final bool canTrack;

  factory OrderActions.fromJson(Json? j) => j == null
      ? const OrderActions()
      : OrderActions(
          canCancel: j['can_cancel'] == true,
          canRate: j['can_rate'] == true,
          canReturn: j['can_return'] == true,
          canReport: j['can_report'] == true,
          canReorder: j['can_reorder'] == true,
          canTrack: j['can_track'] == true,
        );
}

class OrderDetail {
  const OrderDetail({
    required this.summary,
    this.subtotal = 0,
    this.discount = 0,
    this.voucherCode,
    this.shippingFee = 0,
    this.serviceFee = 0,
    this.shippingOption,
    this.estimatedFrom,
    this.estimatedTo,
    this.paymentMethod,
    this.paymentStatus,
    this.shipTo,
    this.waybillNumber,
    this.logisticsName,
    this.courier,
    this.events = const [],
    this.feedback,
    this.cancelReason,
    this.cancelledAt,
    this.deliveredAt,
    this.returnRequest,
    this.actions = const OrderActions(),
  });

  final OrderSummaryItem summary;
  final double subtotal;
  final double discount;
  final String? voucherCode;
  final double shippingFee;
  final double serviceFee;
  final String? shippingOption;
  final DateTime? estimatedFrom;
  final DateTime? estimatedTo;
  final String? paymentMethod;
  final String? paymentStatus;
  final ShipTo? shipTo;
  final String? waybillNumber;
  final String? logisticsName;
  final CourierInfo? courier;
  final List<TrackingEvent> events;
  final String? feedback;
  final String? cancelReason;
  final DateTime? cancelledAt;
  final DateTime? deliveredAt;
  final ReturnRequest? returnRequest;
  final OrderActions actions;

  int get id => summary.id;
  OrderStatus get status => summary.status;

  /// When the given canonical status was first recorded, if it was.
  DateTime? reachedAt(OrderStatus s) {
    for (final e in events) {
      if (e.status == s.apiValue) return e.occurredAt;
    }
    return null;
  }

  factory OrderDetail.fromJson(Json j) {
    final eta = mapOrNull(j['estimated_delivery']);
    return OrderDetail(
      summary: OrderSummaryItem.fromJson(j),
      subtotal: toDouble(j['subtotal']),
      discount: toDouble(j['discount']),
      voucherCode: toStr(j['voucher_code']),
      shippingFee: toDouble(j['shipping_fee']),
      serviceFee: toDouble(j['service_fee']),
      shippingOption: toStr(j['shipping_option']),
      estimatedFrom: eta == null ? null : toDate(eta['from']),
      estimatedTo: eta == null ? null : toDate(eta['to']),
      paymentMethod: toStr(j['payment_method']),
      paymentStatus: toStr(j['payment_status']),
      shipTo: mapOrNull(j['ship_to']) == null ? null : ShipTo.fromJson(mapOrNull(j['ship_to'])!),
      waybillNumber: toStr(j['waybill_number']),
      logisticsName: toStr(mapOrNull(j['logistics'])?['name']),
      courier: mapOrNull(j['courier']) == null ? null : CourierInfo.fromJson(mapOrNull(j['courier'])!),
      events: listOf(j['events'], TrackingEvent.fromJson),
      feedback: toStr(j['feedback']),
      cancelReason: toStr(j['cancel_reason']),
      cancelledAt: toDate(j['cancelled_at']),
      deliveredAt: toDate(j['delivered_at']),
      returnRequest: mapOrNull(j['return_request']) == null ? null : ReturnRequest.fromJson(mapOrNull(j['return_request'])!),
      actions: OrderActions.fromJson(mapOrNull(j['actions'])),
    );
  }
}

class OrderList {
  const OrderList({required this.orders, required this.counts});

  final List<OrderSummaryItem> orders;
  final Map<OrderTab, int> counts;
}

Map<OrderTab, int> parseOrderCounts(Json? j) {
  final counts = <OrderTab, int>{};
  (j ?? {}).forEach((k, v) => counts[OrderTab.fromApi(k)] = toInt(v));
  return counts;
}

class OrderOptions {
  const OrderOptions({
    this.cancelReasons = const [],
    this.reportCategories = const [],
    this.returnReasons = const [],
    this.refundMethods = const [],
    this.returnWindowDays = 7,
  });

  final List<String> cancelReasons;
  final List<String> reportCategories;
  final List<String> returnReasons;

  /// (code, name)
  final List<(String, String)> refundMethods;
  final int returnWindowDays;

  factory OrderOptions.fromJson(Json j) => OrderOptions(
        cancelReasons: (j['cancel_reasons'] as List?)?.map((e) => '$e').toList() ?? const [],
        reportCategories: (j['report_categories'] as List?)?.map((e) => '$e').toList() ?? const [],
        returnReasons: (j['return_reasons'] as List?)?.map((e) => '$e').toList() ?? const [],
        refundMethods: listOf(j['refund_methods'], (m) => ('${m['code']}', '${m['name']}')),
        returnWindowDays: toInt(j['return_window_days'], 7),
      );
}

/// BUY-C13 reorder candidate.
class ReorderItem {
  const ReorderItem({
    required this.orderId,
    required this.productName,
    required this.lastPrice,
    this.product,
    this.sellerName,
    this.currentPrice,
    this.priceChanged = false,
    this.available = false,
  });

  final int orderId;
  final Product? product;
  final String productName;
  final String? sellerName;
  final double lastPrice;
  final double? currentPrice;
  final bool priceChanged;
  final bool available;

  factory ReorderItem.fromJson(Json j) => ReorderItem(
        orderId: toInt(j['order_id']),
        product: mapOrNull(j['product']) == null ? null : Product.fromJson(mapOrNull(j['product'])!),
        productName: j['product_name'] as String? ?? '',
        sellerName: toStr(j['seller_name']),
        lastPrice: toDouble(j['last_price']),
        currentPrice: toDoubleOrNull(j['current_price']),
        priceChanged: j['price_changed'] == true,
        available: j['available'] == true,
      );
}

/// BUY-A09 Support Ticket.
class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.reference,
    required this.subject,
    required this.status,
    this.category,
    this.orderNumber,
    this.orderId,
    this.adminNotes,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String reference;
  final String subject;

  /// open | under_review | resolved | dismissed
  final String status;
  final String? category;
  final String? orderNumber;
  final int? orderId;
  final String? adminNotes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory SupportTicket.fromJson(Json j) => SupportTicket(
        id: toInt(j['id']),
        reference: j['reference'] as String? ?? '',
        subject: j['subject'] as String? ?? '',
        status: j['status'] as String? ?? 'open',
        category: toStr(j['category']),
        orderNumber: toStr(j['order_number']),
        orderId: j['order_id'] == null ? null : toInt(j['order_id']),
        adminNotes: toStr(j['admin_notes']),
        createdAt: toDate(j['created_at']),
        updatedAt: toDate(j['updated_at']),
      );
}

/// Result of placing an order.
class PlacedCheckout {
  const PlacedCheckout({required this.checkoutRef, required this.message, required this.orders, required this.total});

  final String checkoutRef;
  final String message;
  final List<OrderSummaryItem> orders;
  final double total;
}
