import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picksell/core/theme/ps_theme.dart';
import 'package:picksell/services/checkout_service.dart';
import 'package:picksell/userpages/buyer/cart/checkout_page.dart';
import 'package:picksell/userpages/buyer/orders/order_details_page.dart';

import 'support/fake_api.dart';

Widget _app(Widget home) => MaterialApp(theme: PsTheme.light, home: home);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Map<String, dynamic> _sent(FakeBuyerApi api, String method, String path) =>
    jsonDecode(api.calls(method, path).last.body) as Map<String, dynamic>;

/// The row sits under the Place Order bar until scrolled clear of it.
Future<void> _openVouchers(WidgetTester tester) async {
  await tester.drag(find.byType(ListView).first, const Offset(0, -400));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Store & PickSell Vouchers'));
}

void main() {
  final api = FakeBuyerApi();

  setUp(() async {
    api.reset();
    await api.install();
  });

  group('CheckoutService vouchers', () {
    test('reads the offer and picks; nothing extra is sent when none are picked', () async {
      final checkout = CheckoutService();
      final none = await checkout.quote(lineIds: [1, 2]);
      expect(_sent(api, 'POST', '/buyer/checkout/quote').keys, isNot(contains('store_vouchers')));
      expect(none.vouchers.stores.single.options.single.code, 'SAVE50');
      expect(none.vouchers.platform.single.code, 'PICK20');
      expect(none.vouchers.pickedCount, 0);
      expect(none.payable, 1000);

      final both = await checkout.quote(lineIds: [1, 2], vouchers: const VoucherPicks(stores: {3: 61}, platform: 62));
      expect(_sent(api, 'POST', '/buyer/checkout/quote'), allOf(containsPair('store_vouchers', {'3': 61}), containsPair('platform_voucher', 62)));
      expect(both.vouchers.pickedStores, {3: 61});
      expect(both.vouchers.pickedPlatform, 62);
      expect(both.vouchers.total, 70);
      expect(both.payable, 1000 - 70);

      final typed = await checkout.quote(lineIds: [1, 2], code: ' pick20 ');
      expect(_sent(api, 'POST', '/buyer/checkout/quote'), containsPair('code', 'pick20'));
      expect(typed.vouchers.pickedPlatform, 62);

      // Below the minimum spend the server drops the pick and says why.
      final small = await checkout.quote(lineIds: [1], vouchers: const VoucherPicks(stores: {3: 61}));
      expect(small.vouchers.pickedStores, isEmpty);
      expect(small.vouchers.error, 'SAVE50: Spend ₱100.00 more to use this voucher.');
    });
  });

  testWidgets('checkout: pick a store and a PickSell voucher, see the saving, place with them', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(const CheckoutPage(lineIds: [1, 2])));
    await tester.pumpAndSettle();

    expect(find.text('Store & PickSell Vouchers'), findsOneWidget);
    expect(find.text('2 available for this order'), findsOneWidget);

    await _openVouchers(tester);
    await tester.pumpAndSettle();
    expect(find.text('ISLAND THREADS VOUCHERS'), findsOneWidget);
    expect(find.text('PICKSELL VOUCHERS'), findsOneWidget);
    await tester.tap(find.text('SAVE50'));
    await tester.tap(find.text('PICK20'));
    await tester.pump();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('SAVE50 · PICK20'), findsOneWidget);
    expect(find.text('Store Voucher'), findsOneWidget);
    expect(find.text('PickSell Voucher'), findsOneWidget);
    expect(find.text('You save ₱70.00'), findsOneWidget);
    expect(find.text('₱930.00'), findsWidgets);

    await tester.tap(find.text('Place Order'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(_sent(api, 'POST', '/buyer/checkout'), allOf(containsPair('store_vouchers', {'3': 61}), containsPair('platform_voucher', 62)));
  });

  testWidgets('checkout: a voucher used up since the quote is explained and dropped', (tester) async {
    _phone(tester);
    api.usedUp = true;
    await tester.pumpWidget(_app(const CheckoutPage(lineIds: [1, 2])));
    await tester.pumpAndSettle();
    await _openVouchers(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('SAVE50'));
    await tester.pump();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Place Order'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('A voucher can’t be used'), findsOneWidget);
    expect(find.text('SAVE50: You have already used this voucher.'), findsOneWidget);
    await tester.tap(find.text('Review vouchers'));
    await tester.pumpAndSettle();

    // Re-priced without it, and the picker opens again.
    expect(_sent(api, 'POST', '/buyer/checkout/quote').keys, isNot(contains('store_vouchers')));
    expect(find.text('PICKSELL VOUCHERS'), findsOneWidget);
  });

  testWidgets('order details: the website’s breakdown for a parcel shared with other items', (tester) async {
    _phone(tester);
    api.orderDetail = {
      'id': 501,
      'order_number': 'PS-10000001',
      'status': 'placed',
      'tab': 'to_ship',
      'seller': FakeBuyerApi.shirt['seller'],
      'product_id': 7,
      'product_name': 'Cotton Basic Tee',
      'quantity': 1,
      'unit_price': 540,
      'total': 540,
      'subtotal': 540,
      'discount': 110,
      'shipping_fee': 95,
      'store_discount': 60,
      'platform_discount': 50,
      'parcel_items': 2,
      'parcel_subtotal': 900,
      'parcel_total': 945,
      'payment_method': 'Cash on Delivery',
      'events': [],
      'actions': {},
    };
    await tester.pumpWidget(_app(const OrderDetailsPage(orderId: 501)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Parcel total (COD)'), 200);

    expect(find.text('Store voucher'), findsOneWidget);
    expect(find.text('-₱60.00'), findsOneWidget);
    expect(find.text('PickSell voucher'), findsOneWidget);
    expect(find.text('For this parcel of 2 items'), findsOneWidget);
    expect(find.text('₱945.00'), findsOneWidget);
  });
}
