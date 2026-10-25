import '../core/network/api_client.dart';
import '../models/cart.dart';
import '../models/catalog.dart';
import '../models/json.dart';
import '../models/order.dart';

/// API-C05 Checkout Service.
class CheckoutService {
  CheckoutService({ApiClient? client}) : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  Future<CartQuote> quote({
    required List<int> lineIds,
    String shippingOption = 'standard',
    String? voucherCode,
  }) async {
    final j = await _api.postJson('/buyer/checkout/quote', {
      'item_ids': lineIds,
      'shipping_option': shippingOption,
      if (voucherCode != null && voucherCode.isNotEmpty) 'voucher_code': voucherCode,
    });
    return CartQuote.fromJson(mapOrNull(j['quote']));
  }

  /// Throws [ApiException]: 409 = stock changed (data['quote'] has the
  /// fresh quote), 422 = validation (voucher_code / address_id / payment_method).
  Future<PlacedCheckout> place({
    required List<int> lineIds,
    required int addressId,
    required String paymentMethod,
    String shippingOption = 'standard',
    String? voucherCode,
  }) async {
    final j = await _api.postJson('/buyer/checkout', {
      'item_ids': lineIds,
      'address_id': addressId,
      'payment_method': paymentMethod,
      'shipping_option': shippingOption,
      if (voucherCode != null && voucherCode.isNotEmpty) 'voucher_code': voucherCode,
    });
    return PlacedCheckout(
      checkoutRef: j['checkout_ref'] as String? ?? '',
      message: j['message'] as String? ?? 'Order placed!',
      orders: listOf(j['orders'], OrderSummaryItem.fromJson),
      total: toDouble(mapOrNull(j['totals'])?['total']),
    );
  }

  /// Vouchers checked against the selected lines (checkout sheet).
  Future<VoucherSheetData> vouchersFor(List<int> lineIds) async {
    final j = await _api.getJson('/buyer/vouchers', query: {'item_ids[]': lineIds});
    return VoucherSheetData(platform: listOf(j['platform'], Voucher.fromJson), store: listOf(j['store'], Voucher.fromJson));
  }

  /// BUY-A07 Voucher Wallet.
  Future<VoucherWallet> wallet() async {
    final j = await _api.getJson('/buyer/vouchers');
    return VoucherWallet(
      available: listOf(j['available'], Voucher.fromJson),
      used: listOf(j['used'], Voucher.fromJson),
      expired: listOf(j['expired'], Voucher.fromJson),
    );
  }

  Future<List<ShippingOption>> shippingOptions() async =>
      listOf((await _api.getJson('/shipping-options'))['shipping_options'], ShippingOption.fromJson);

  Future<List<PaymentMethodOption>> paymentMethods() async =>
      listOf((await _api.getJson('/payment-methods'))['payment_methods'], PaymentMethodOption.fromJson);
}
