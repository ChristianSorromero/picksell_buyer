import '../core/network/api_client.dart';
import '../models/address.dart';
import '../models/cart.dart';
import '../models/checkout_vouchers.dart';
import '../models/json.dart';
import '../models/order.dart';

/// The server-priced checkout and where it will be delivered.
class CheckoutQuote {
  const CheckoutQuote({required this.quote, required this.deliveryAddress, required this.shipTo, this.vouchers = const CheckoutVouchers()});

  final CartQuote quote;

  /// The buyer's default (profile) address.
  final DeliveryAddress deliveryAddress;

  /// Where this checkout ships: the default address or the chosen address-book entry.
  final CheckoutShipTo shipTo;

  /// Store and PickSell vouchers on offer, the ones picked and what they save.
  final CheckoutVouchers vouchers;

  /// What the rider collects: the quote's total less the picked store and PickSell vouchers.
  double get payable => (quote.totals.total - vouchers.total).clamp(0, double.infinity).toDouble();
}

/// The store vouchers (seller id → voucher id) and PickSell voucher picked for a checkout.
class VoucherPicks {
  const VoucherPicks({this.stores = const {}, this.platform});

  final Map<int, int> stores;
  final int? platform;

  bool get isEmpty => stores.isEmpty && platform == null;

  Map<String, dynamic> toJson() => {
        if (stores.isNotEmpty) 'store_vouchers': {for (final e in stores.entries) '${e.key}': e.value},
        if (platform != null) 'platform_voucher': platform,
      };
}

/// API-C05 Checkout Service. Same rules as the website's checkout: Cash on
/// Delivery to the default address or a saved one ([addressId]), a product's
/// own voucher code, no fees.
class CheckoutService {
  CheckoutService({ApiClient? client}) : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  /// [addressId] null ships to the default address (and is not sent).
  ///
  /// [vouchers] are the store / PickSell vouchers picked so far; a typed [code]
  /// picks the voucher it belongs to (not case-sensitive, unlike [voucherCode],
  /// which is a product's own code).
  Future<CheckoutQuote> quote({
    required List<int> lineIds,
    String? voucherCode,
    int? addressId,
    VoucherPicks vouchers = const VoucherPicks(),
    String? code,
  }) async {
    final j = await _api.postJson('/buyer/checkout/quote', {
      'item_ids': lineIds,
      if (voucherCode != null && voucherCode.isNotEmpty) 'voucher_code': voucherCode,
      if (addressId != null) 'address_id': addressId,
      ...vouchers.toJson(),
      if (code != null && code.trim().isNotEmpty) 'code': code.trim(),
    });
    final v = mapOrNull(j['vouchers']);
    final delivery = DeliveryAddress.fromJson(mapOrNull(j['delivery_address']) ?? const {});
    final shipTo = mapOrNull(j['ship_to']);
    return CheckoutQuote(
      quote: CartQuote.fromJson(mapOrNull(j['quote'])),
      deliveryAddress: delivery,
      shipTo: shipTo == null ? CheckoutShipTo.fromDefault(delivery) : CheckoutShipTo.fromJson(shipTo),
      vouchers: v == null ? const CheckoutVouchers() : CheckoutVouchers.fromJson(v),
    );
  }

  /// Throws [ApiException]: 422 with `item_ids` (unavailable or short of
  /// stock), `address` (address incomplete), `address_id` (not yours / removed)
  /// or `vouchers` (a picked voucher can no longer be used).
  Future<PlacedCheckout> place({
    required List<int> lineIds,
    String? voucherCode,
    int? addressId,
    VoucherPicks vouchers = const VoucherPicks(),
  }) async {
    final j = await _api.postJson('/buyer/checkout', {
      'item_ids': lineIds,
      'payment_method': 'cod',
      if (voucherCode != null && voucherCode.isNotEmpty) 'voucher_code': voucherCode,
      if (addressId != null) 'address_id': addressId,
      ...vouchers.toJson(),
    });
    return PlacedCheckout(
      checkoutRef: j['checkout_ref'] as String? ?? '',
      message: j['message'] as String? ?? 'Order placed!',
      orders: listOf(j['orders'], OrderSummaryItem.fromJson),
      total: toDouble(j['total']),
    );
  }
}
