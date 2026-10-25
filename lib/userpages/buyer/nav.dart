import 'package:flutter/material.dart';

import '../../components/components.dart';
import '../../models/order.dart';
import 'cart/checkout_page.dart';
import 'orders/order_details_page.dart';
import 'orders/orders_page.dart';
import 'shop/product_detail_page.dart';
import 'shop/product_list_page.dart';
import 'shop/store_page.dart';

/// Selected bottom-nav tab. Any screen can switch tabs, e.g. "View Cart"
/// from a product page: `ShellNav.goTo(context, BuyerTab.cart)`.
class ShellNav {
  ShellNav._();

  static final ValueNotifier<BuyerTab> tab = ValueNotifier(BuyerTab.home);

  /// Pops back to the shell and selects [target].
  static void goTo(BuildContext context, BuyerTab target) {
    Navigator.of(context).popUntil((r) => r.isFirst);
    tab.value = target;
  }
}

Route<T> _route<T>(Widget page) => MaterialPageRoute<T>(builder: (_) => page);

Future<void> openProduct(BuildContext context, int productId) =>
    Navigator.of(context).push(_route(ProductDetailPage(productId: productId)));

Future<void> openStore(BuildContext context, int sellerId) =>
    Navigator.of(context).push(_route(StorePage(sellerId: sellerId)));

Future<void> openProductList(BuildContext context, {String? title, String? search, String? category, bool onSale = false}) =>
    Navigator.of(context).push(_route(ProductListPage(title: title, initialSearch: search, initialCategory: category, onSale: onSale)));

Future<void> openOrder(BuildContext context, int orderId) =>
    Navigator.of(context).push(_route(OrderDetailsPage(orderId: orderId)));

Future<void> openOrders(BuildContext context, {OrderTab initial = OrderTab.all}) =>
    Navigator.of(context).push(_route(OrdersPage(initial: initial)));

/// Checkout for specific cart lines (Cart "Check Out" or "Buy Now").
Future<void> openCheckout(BuildContext context, List<int> lineIds, {String? voucherCode}) =>
    Navigator.of(context).push(_route(CheckoutPage(lineIds: lineIds, voucherCode: voucherCode)));
