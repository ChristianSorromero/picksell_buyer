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

/// The vouchers picked for a checkout: per store either a store voucher
/// (seller id → voucher id) or a product voucher (seller id → code), and one
/// PickSell voucher.
class VoucherPicks {
  const VoucherPicks({this.stores = const {}, this.products = const {}, this.platform});

  final Map<int, int> stores;
  final Map<int, String> products;
  final int? platform;

  bool get isEmpty => stores.isEmpty && products.isEmpty && platform == null;

  /// [sellerId]'s pick changed to a store voucher, a product voucher, or neither.
  VoucherPicks withStore(int sellerId, {int? storeVoucher, String? productCode}) => VoucherPicks(
        stores: {...stores}..remove(sellerId)..addAll({if (storeVoucher != null) sellerId: storeVoucher}),
        products: {...products}..remove(sellerId)..addAll({if (productCode != null) sellerId: productCode}),
        platform: platform,
      );

  VoucherPicks withPlatform(int? id) => VoucherPicks(stores: stores, products: products, platform: id);

  Map<String, dynamic> toJson() => {
        if (stores.isNotEmpty) 'store_vouchers': {for (final e in stores.entries) '${e.key}': e.value},
        if (products.isNotEmpty) 'product_vouchers': {for (final e in products.entries) '${e.key}': e.value},
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
  /// [vouchers] are the store, product and PickSell vouchers picked so far; a
  /// typed [code] picks the voucher it is among [codeFor]'s: 'platform' or a
  /// seller id (store and PickSell codes are not case-sensitive, product codes
  /// are). [voucherCode] is a product page's code, used for the stores it fits.
  Future<CheckoutQuote> quote({
    required List<int> lineIds,
    String? voucherCode,
    int? addressId,
    VoucherPicks vouchers = const VoucherPicks(),
    String? code,
    String? codeFor,
    Map<int, int> carriers = const {},
  }) async {
    final j = await _api.postJson('/buyer/checkout/quote', {
      'item_ids': lineIds,
      if (voucherCode != null && voucherCode.isNotEmpty) 'voucher_code': voucherCode,
      if (addressId != null) 'address_id': addressId,
      ...vouchers.toJson(),
      if (carriers.isNotEmpty) 'carriers': {for (final e in carriers.entries) '${e.key}': e.value},
      if (code != null && code.trim().isNotEmpty) 'code': code.trim(),
      if (code != null && codeFor != null) 'code_for': codeFor,
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
    String? checkoutKey,
    String? voucherCode,
    int? addressId,
    VoucherPicks vouchers = const VoucherPicks(),
    Map<int, int> carriers = const {},
  }) async {
    final j = await _api.postJson('/buyer/checkout', {
      'item_ids': lineIds,
      'payment_method': 'cod',
      if (checkoutKey != null) 'checkout_key': checkoutKey,
      if (voucherCode != null && voucherCode.isNotEmpty) 'voucher_code': voucherCode,
      if (addressId != null) 'address_id': addressId,
      ...vouchers.toJson(),
      if (carriers.isNotEmpty) 'carriers': {for (final e in carriers.entries) '${e.key}': e.value},
    });
    return PlacedCheckout(
      checkoutRef: j['checkout_ref'] as String? ?? '',
      message: j['message'] as String? ?? 'Order placed!',
      orders: listOf(j['orders'], OrderSummaryItem.fromJson),
      total: toDouble(j['total']),
    );
  }
}
