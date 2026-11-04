import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:picksell/components/commerce/ps_product_card.dart';
import 'package:picksell/core/network/api_client.dart';
import 'package:picksell/core/theme/ps_theme.dart';
import 'package:picksell/models/catalog.dart';
import 'package:picksell/models/chat.dart';
import 'package:picksell/userpages/chats_page.dart';

import 'support/fake_api.dart';

/// The app follows the main PickSell app's buyer API (/api/mobile): seller vacation pauses
/// and automatic seller replies come from there.
Widget _app(Widget home) => MaterialApp(theme: PsTheme.light, home: home);

Map<String, dynamic> _product({required bool available, bool onVacation = false}) => {
      'id': 7,
      'name': 'Desk Lamp',
      'price': 450.0,
      'stock': 12,
      'is_available': available,
      'seller': {'id': 3, 'name': 'Lamp House', 'location': 'Cebu City', 'verified': true, 'on_vacation': onVacation},
    };

void main() {
  setUp(() async => FakeBuyerApi().install());

  test('the default API base URL is the canonical /api/mobile', () {
    expect(ApiConfig.baseUrl, endsWith('/api/mobile'));
  });

  group('seller vacation', () {
    test('a vacation pause is not reported as a stock-out', () {
      final away = Product.fromJson(_product(available: false, onVacation: true));
      expect(away.inStock, isFalse);
      expect(away.sellerOnVacation, isTrue);
      expect(away.unavailableLabel, 'Seller away');

      final soldOut = Product.fromJson(_product(available: false));
      expect(soldOut.unavailableLabel, 'Sold out');
      expect(Product.fromJson(_product(available: true)).unavailableLabel, isNull);
    });

    test('the seller summary carries the vacation flag', () {
      expect(SellerSummary.fromJson({'id': 3, 'name': 'Lamp House', 'on_vacation': true}).onVacation, isTrue);
      expect(SellerSummary.fromJson({'id': 3, 'name': 'Lamp House'}).onVacation, isFalse);
    });

    testWidgets('the product card says the seller is away', (tester) async {
      await tester.pumpWidget(_app(Scaffold(
        body: SizedBox(
          width: 180,
          child: PsProductCard(product: Product.fromJson(_product(available: false, onVacation: true)), onTap: () {}),
        ),
      )));
      await tester.pump();

      expect(find.text('SELLER AWAY'), findsOneWidget);
      expect(find.text('SOLD OUT'), findsNothing);
    });
  });

  group('automatic seller replies', () {
    test('are recognised, unmarked for display, and labelled in the contact preview', () {
      final auto = ChatMessage.fromJson({
        'id': 2, 'sender_id': 3, 'body': '[Auto-reply] Thanks for your message!', 'created_at': '2026-11-04T14:30:00+08:00', 'is_mine': false,
      });
      expect(auto.isAutoReply, isTrue);
      expect(auto.displayBody, 'Thanks for your message!');

      final typed = ChatMessage.fromJson({
        'id': 3, 'sender_id': 3, 'body': 'Yes, it is in stock.', 'created_at': '2026-11-04T14:31:00+08:00', 'is_mine': false,
      });
      expect(typed.isAutoReply, isFalse);
      expect(typed.displayBody, 'Yes, it is in stock.');

      const contact = ChatContact(id: 3, name: 'Lamp House', initials: 'LH', lastMessage: '[Auto-reply] Away until Friday.');
      expect(contact.lastMessagePreview, 'Auto-reply: Away until Friday.');
    });

    testWidgets('show as an automatic reply in the conversation', (tester) async {
      ApiClient.instance = ApiClient(
        client: MockClient((r) async => http.Response(
              jsonEncode({
                'messages': [
                  {'id': 1, 'sender_id': 9, 'body': 'Is the lamp available?', 'created_at': '2026-11-04T14:29:00+08:00', 'is_mine': true},
                  {'id': 2, 'sender_id': 3, 'body': '[Auto-reply] Thanks for your message!', 'created_at': '2026-11-04T14:29:01+08:00', 'is_mine': false},
                ],
              }),
              200,
              headers: {'content-type': 'application/json'},
            )),
      );
      const contact = ChatContact(id: 3, name: 'Lamp House', initials: 'LH', lastMessage: '');

      await tester.pumpWidget(_app(const ChatConversationPage(contact: contact)));
      await tester.pumpAndSettle();

      expect(find.text('Automatic reply'), findsOneWidget);
      expect(find.text('Thanks for your message!'), findsOneWidget);
      expect(find.textContaining('[Auto-reply]'), findsNothing);
      expect(find.text('Is the lamp available?'), findsOneWidget);
    });
  });
}
