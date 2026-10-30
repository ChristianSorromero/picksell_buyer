import '../core/network/api_client.dart';
import '../models/address.dart';
import '../models/cart.dart';
import '../models/json.dart';
import '../models/order.dart';

/// The server-priced checkout and where it will be delivered.
class CheckoutQuote {
  const CheckoutQuote({required this.quote, required this.deliveryAddress});

  final CartQuote quote;
  final DeliveryAddress deliveryAddress;
}

/// API-C05 Checkout Service. Same rules as the website's checkout: Cash on
/// Delivery to the profile address, a product's own voucher code, no fees.
class CheckoutService {
  CheckoutService({ApiClient? client}) : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  Future<CheckoutQuote> quote({required List<int> lineIds, String? voucherCode}) async {
    final j = await _api.postJson('/buyer/checkout/quote', {
      'item_ids': lineIds,
      if (voucherCode != null && voucherCode.isNotEmpty) 'voucher_code': voucherCode,
    });
    return CheckoutQuote(
      quote: CartQuote.fromJson(mapOrNull(j['quote'])),
      deliveryAddress: DeliveryAddress.fromJson(mapOrNull(j['delivery_address']) ?? const {}),
    );
  }

  /// Throws [ApiException]: 422 with `item_ids` (unavailable or short of
  /// stock) or `address` (profile address incomplete).
  Future<PlacedCheckout> place({required List<int> lineIds, String? voucherCode}) async {
    final j = await _api.postJson('/buyer/checkout', {
      'item_ids': lineIds,
      'payment_method': 'cod',
      if (voucherCode != null && voucherCode.isNotEmpty) 'voucher_code': voucherCode,
    });
    return PlacedCheckout(
      checkoutRef: j['checkout_ref'] as String? ?? '',
      message: j['message'] as String? ?? 'Order placed!',
      orders: listOf(j['orders'], OrderSummaryItem.fromJson),
      total: toDouble(j['total']),
    );
  }
}
