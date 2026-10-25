import 'catalog.dart';
import 'json.dart';

/// Why a cart line can't be checked out right now.
enum CartLineIssue {
  unavailable('This item is no longer available.'),
  outOfStock('Out of stock.'),
  insufficientStock('Not enough stock for this quantity.');

  const CartLineIssue(this.message);

  final String message;

  static CartLineIssue? fromApi(Object? v) => switch (v) {
        'unavailable' => unavailable,
        'out_of_stock' => outOfStock,
        'insufficient_stock' => insufficientStock,
        _ => null,
      };
}

/// COM-C12 Cart Item.
class CartLine {
  const CartLine({
    required this.id,
    required this.product,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    this.variationIds = const [],
    this.variationLabel,
    this.availableStock = 0,
    this.discount = 0,
    this.issue,
  });

  final int id;
  final Product product;
  final int quantity;
  final double unitPrice;
  final double lineTotal;
  final List<int> variationIds;
  final String? variationLabel;
  final int availableStock;
  final double discount;
  final CartLineIssue? issue;

  bool get purchasable => issue == null;

  factory CartLine.fromJson(Json j) => CartLine(
        id: toInt(j['cart_item_id']),
        product: Product.fromJson(mapOrNull(j['product']) ?? const {}),
        quantity: toInt(j['quantity'], 1),
        unitPrice: toDouble(j['unit_price']),
        lineTotal: toDouble(j['line_total']),
        variationIds: (j['variation_ids'] as List?)?.map(toInt).toList() ?? const [],
        variationLabel: toStr(j['variation_label']),
        availableStock: toInt(j['available_stock']),
        discount: toDouble(j['discount']),
        issue: CartLineIssue.fromApi(j['issue']),
      );
}

/// COM-C13 Seller Cart Group.
class CartGroup {
  const CartGroup({
    required this.seller,
    required this.items,
    required this.subtotal,
    this.discount = 0,
    this.shippingFee = 0,
  });

  final SellerBrief? seller;
  final List<CartLine> items;
  final double subtotal;
  final double discount;
  final double shippingFee;

  factory CartGroup.fromJson(Json j) => CartGroup(
        seller: mapOrNull(j['seller']) == null ? null : SellerBrief.fromJson(mapOrNull(j['seller'])!),
        items: listOf(j['items'], CartLine.fromJson),
        subtotal: toDouble(j['subtotal']),
        discount: toDouble(j['discount']),
        shippingFee: toDouble(j['shipping_fee']),
      );
}

/// COM-C17 Order Cost Breakdown numbers.
class CostTotals {
  const CostTotals({
    this.merchandiseSubtotal = 0,
    this.shippingTotal = 0,
    this.discountTotal = 0,
    this.serviceFee = 0,
    this.total = 0,
  });

  final double merchandiseSubtotal;
  final double shippingTotal;
  final double discountTotal;
  final double serviceFee;
  final double total;

  factory CostTotals.fromJson(Json? j) => j == null
      ? const CostTotals()
      : CostTotals(
          merchandiseSubtotal: toDouble(j['merchandise_subtotal']),
          shippingTotal: toDouble(j['shipping_total']),
          discountTotal: toDouble(j['discount_total']),
          serviceFee: toDouble(j['service_fee']),
          total: toDouble(j['total']),
        );
}

class AppliedVoucher {
  const AppliedVoucher({required this.code, required this.title, required this.discount});

  final String code;
  final String title;
  final double discount;

  factory AppliedVoucher.fromJson(Json j) =>
      AppliedVoucher(code: j['code'] as String? ?? '', title: j['title'] as String? ?? '', discount: toDouble(j['discount']));
}

/// The server-priced cart / checkout quote. Every number shown before
/// placing an order comes from here.
class CartQuote {
  const CartQuote({
    this.groups = const [],
    this.shippingOption,
    this.voucher,
    this.voucherError,
    this.hasIssues = false,
    this.itemCount = 0,
    this.totals = const CostTotals(),
  });

  final List<CartGroup> groups;
  final ShippingOption? shippingOption;
  final AppliedVoucher? voucher;
  final String? voucherError;
  final bool hasIssues;
  final int itemCount;
  final CostTotals totals;

  List<CartLine> get lines => [for (final g in groups) ...g.items];
  bool get isEmpty => groups.isEmpty;

  factory CartQuote.fromJson(Json? j) => j == null
      ? const CartQuote()
      : CartQuote(
          groups: listOf(j['groups'], CartGroup.fromJson),
          shippingOption: mapOrNull(j['shipping_option']) == null ? null : ShippingOption.fromJson(mapOrNull(j['shipping_option'])!),
          voucher: mapOrNull(j['voucher']) == null ? null : AppliedVoucher.fromJson(mapOrNull(j['voucher'])!),
          voucherError: toStr(j['voucher_error']),
          hasIssues: j['has_issues'] == true,
          itemCount: toInt(j['item_count']),
          totals: CostTotals.fromJson(mapOrNull(j['totals'])),
        );
}

class PaymentMethodOption {
  const PaymentMethodOption({required this.code, required this.name, this.description = '', this.available = false});

  final String code;
  final String name;
  final String description;
  final bool available;

  factory PaymentMethodOption.fromJson(Json j) => PaymentMethodOption(
        code: j['code'] as String? ?? '',
        name: j['name'] as String? ?? '',
        description: j['description'] as String? ?? '',
        available: j['available'] == true,
      );
}

class VoucherSheetData {
  const VoucherSheetData({this.platform = const [], this.store = const []});

  final List<Voucher> platform;
  final List<Voucher> store;
}

class VoucherWallet {
  const VoucherWallet({this.available = const [], this.used = const [], this.expired = const []});

  final List<Voucher> available;
  final List<Voucher> used;
  final List<Voucher> expired;
}
