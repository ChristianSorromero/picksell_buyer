import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picksell/core/theme/ps_theme.dart';
import 'package:picksell/models/address.dart';
import 'package:picksell/services/address_book_service.dart';
import 'package:picksell/services/checkout_service.dart';
import 'package:picksell/userpages/buyer/account/address_book_page.dart';
import 'package:picksell/userpages/buyer/cart/checkout_page.dart';

import 'support/fake_api.dart';

Widget _app(Widget home) => MaterialApp(theme: PsTheme.light, home: home);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

const _office = AddressInput(
  label: 'Work',
  recipientName: 'Ana Cruz',
  contactNo: '09175550101',
  province: 'Cebu',
  municipality: 'Cebu City',
  barangay: 'Lahug',
  street: 'Gorordo Ave',
  houseNo: '5',
  pin: GeoPin(10.3312, 123.8977),
);

Map<String, dynamic> _sent(FakeBuyerApi api, String method, String path) =>
    jsonDecode(api.calls(method, path).last.body) as Map<String, dynamic>;

void main() {
  final api = FakeBuyerApi();

  setUp(() async {
    api.reset();
    await api.install();
  });

  group('AddressBookService', () {
    test('adds, edits (keeping the pin), sets default and removes like the website', () async {
      final service = AddressBookService();
      var book = await service.load();
      expect(book.addresses, isEmpty);
      expect(book.max, 10);
      expect(book.defaultAddress.municipalityCode, '137404000');

      book = await service.add(_office);
      final work = book.addresses.single;
      expect(work.label, 'Work');
      expect(work.fullAddress, '5, Gorordo Ave, Lahug, Cebu City, Cebu');
      expect(work.pin, const GeoPin(10.3312, 123.8977));
      expect(_sent(api, 'POST', '/buyer/addresses'), allOf(containsPair('contact_no', '09175550101'), containsPair('lat', 10.3312)));

      // An edit sends the pin back so the server keeps it.
      book = await service.update(work.id, const AddressInput(
        label: 'Work', recipientName: 'Ana Cruz', contactNo: '09175550101', province: 'Cebu', municipality: 'Cebu City',
        barangay: 'Lahug', houseNo: '7', pin: GeoPin(10.3312, 123.8977),
      ));
      expect(book.addresses.single.pin, isNotNull);
      expect(_sent(api, 'PATCH', '/buyer/addresses/${work.id}'), containsPair('lng', 123.8977));

      book = await service.makeDefault(work.id);
      expect(book.addresses.single.label, 'Previous default');

      book = await service.remove(book.addresses.single.id);
      expect(book.addresses, isEmpty);
    });

    test('pins the default door and reports how many parcels moved', () async {
      final r = await AddressBookService().pinDefault(const GeoPin(14.6538, 121.0685));
      expect(r.parcelsUpdated, 2);
      expect(r.address.pin, const GeoPin(14.6538, 121.0685));
      expect(_sent(api, 'PATCH', '/buyer/delivery-location'), {'lat': 14.6538, 'lng': 121.0685});
    });

    test('checkout quotes and places to a chosen address; the default sends no address_id', () async {
      final book = await AddressBookService().add(_office);
      final id = book.addresses.single.id;
      final checkout = CheckoutService();

      final home = await checkout.quote(lineIds: [1]);
      expect(home.shipTo.isDefault, isTrue);
      expect(_sent(api, 'POST', '/buyer/checkout/quote').containsKey('address_id'), isFalse);

      final work = await checkout.quote(lineIds: [1], addressId: id);
      expect(work.shipTo.addressId, id);
      expect(work.shipTo.label, 'Work');
      expect(work.shipTo.recipientName, 'Ana Cruz');
      expect(work.deliveryAddress.recipientName, 'Juan Dela Cruz', reason: 'delivery_address stays the default');

      await checkout.place(lineIds: [1], addressId: id);
      expect(_sent(api, 'POST', '/buyer/checkout'), containsPair('address_id', id));
    });
  });

  testWidgets('My Addresses lists the default and saved addresses and removes one after confirming', (tester) async {
    _phone(tester);
    await AddressBookService().add(_office);
    await tester.pumpWidget(_app(const AddressBookPage()));
    await tester.pumpAndSettle();

    expect(find.text('DEFAULT'), findsOneWidget);
    expect(find.text('123, Rizal Ave, Diliman, Quezon City, Metro Manila'), findsOneWidget);
    expect(find.text('Pin your door on the map so riders find it faster.'), findsOneWidget);
    expect(find.text('OTHER ADDRESSES (1/10)'), findsOneWidget);
    expect(find.text('WORK'), findsOneWidget);
    expect(find.text('Pinned on the map'), findsOneWidget);

    await tester.tap(find.byTooltip('Address options').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove').last);
    await tester.pumpAndSettle();
    expect(find.text('Remove this address?'), findsOneWidget);
    await tester.tap(find.text('Remove').last); // the dialog's confirm button
    await tester.pumpAndSettle();

    expect(api.addresses, isEmpty);
    expect(find.text('OTHER ADDRESSES (0/10)'), findsOneWidget);
  });

  testWidgets('checkout: change the delivery address to a saved one', (tester) async {
    _phone(tester);
    await AddressBookService().add(_office);
    await tester.pumpWidget(_app(const CheckoutPage(lineIds: [1, 2])));
    await tester.pumpAndSettle();

    expect(find.text('Juan Dela Cruz'), findsOneWidget);
    expect(find.text('DEFAULT'), findsOneWidget);

    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();
    expect(find.text('Deliver To'), findsOneWidget);
    await tester.tap(find.text('5, Gorordo Ave, Lahug, Cebu City, Cebu'));
    await tester.pumpAndSettle();

    expect(find.text('Order Summary'), findsOneWidget);
    expect(find.text('Ana Cruz'), findsOneWidget);
    expect(find.text('WORK'), findsOneWidget);
    expect(_sent(api, 'POST', '/buyer/checkout/quote'), containsPair('address_id', api.addresses.single['id']));

    await tester.tap(find.text('Place Order'));
    await tester.pumpAndSettle();
    expect(_sent(api, 'POST', '/buyer/checkout'), containsPair('address_id', api.addresses.single['id']));
  });
}
