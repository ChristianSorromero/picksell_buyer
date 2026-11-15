import 'package:flutter_test/flutter_test.dart';
import 'package:picksell/models/cart.dart';
import 'package:picksell/models/catalog.dart';
import 'package:picksell/models/chat.dart';

void main() {
  test('categories follow the website menu: its 8, in its order', () {
    final api = [
      for (final n in ['Beauty', 'Books', 'Clothing', 'Electronics', 'Fashion', 'Food & Grocery', 'Home & Living', 'Pet Supplies', 'Sports', 'Toys'])
        Category(name: n, productCount: n == 'Books' ? 3 : 0),
    ];
    final shown = Category.alignToWeb(api);
    expect(shown.map((c) => c.name), Category.webOrder);
    expect(shown.firstWhere((c) => c.name == 'Books').productCount, 3);
    expect(shown.any((c) => c.name == 'Clothing' || c.name == 'Pet Supplies'), isFalse);
  });

  test('a seller group reads its "Ship with" companies from the quote', () {
    final g = CartGroup.fromJson({
      'seller': {'id': 7, 'name': 'Mabuhay Gadgets'},
      'items': [],
      'subtotal': 100,
      'carrier': '2',
      'shipping': {'ok': true, 'delivery_fee': '65.00', 'estimated_delivery': {'label': 'Nov 18 – 20'}},
      'carriers': [
        {'id': '1', 'name': 'Pickrush', 'is_default': true, 'selected': false, 'ok': true, 'delivery_fee': '60.00'},
        {'id': '2', 'name': 'North Express', 'is_default': false, 'selected': true, 'ok': true, 'delivery_fee': '65.00',
         'estimated_delivery': {'label': 'Nov 18 – 20'}},
        {'id': '3', 'name': 'Far Couriers', 'ok': false, 'message': 'Shipping to this address is not available yet.'},
      ],
    });
    expect(g.carrierId, 2);
    expect(g.deliveryLabel, 'Nov 18 – 20');
    expect(g.carriers, hasLength(3));
    expect(g.carriers.first.isDefault, isTrue);
    expect(g.carriers[1].selected, isTrue);
    expect(g.carriers[1].fee, 65);
    expect(g.carriers[2].ok, isFalse);
    expect(g.carriers[2].message, contains('not available'));
  });

  test('a chat contact with odd or missing fields still loads', () {
    final c = ChatContact.fromJson({'id': '12', 'name': 'Ñora Store', 'unread': '2', 'last_message': null});
    expect(c.id, 12);
    expect(c.unread, 2);
    expect(c.initials, 'Ñ');
    expect(c.lastMessage, '');
  });
}
