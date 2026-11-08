import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:picksell/core/network/api_client.dart';
import 'package:picksell/core/theme/ps_theme.dart';
import 'package:picksell/models/chat.dart';
import 'package:picksell/userpages/chats_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Chat opened from a product: like the website's "Asking about" bar, messages carry the
/// product until the buyer clears it.
void main() {
  late List<Map<String, dynamic>> sent;

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({'auth_token': 'test-token'});
    sent = [];
    var nextId = 1;
    ApiClient.instance = ApiClient(
      client: MockClient((r) async {
        final path = r.url.path.replaceFirst('/api/mobile', '');
        if (r.method == 'GET' && path == '/chat/messages/7') {
          return http.Response(jsonEncode({'messages': []}), 200, headers: {'content-type': 'application/json'});
        }
        if (r.method == 'POST' && path == '/chat/send') {
          final body = jsonDecode(r.body) as Map<String, dynamic>;
          sent.add(body);
          return http.Response(
            jsonEncode({'id': nextId++, 'body': body['body'], 'sender_id': 1, 'is_mine': true, 'created_at': '2026-11-08T10:00:00+08:00'}),
            201,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(jsonEncode({'message': 'unexpected ${r.method} $path'}), 404, headers: {'content-type': 'application/json'});
      }),
    );
  });

  Future<void> open(WidgetTester tester, {int? productId, String? productName}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: PsTheme.light,
        home: ChatConversationPage(
          contact: const ChatContact(id: 7, name: 'Lamp Shop', initials: 'L', lastMessage: ''),
          productId: productId,
          productName: productName,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> send(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
  }

  testWidgets('from a product, messages say which product until the buyer clears it', (tester) async {
    await open(tester, productId: 42, productName: 'Desk Lamp');
    expect(find.text('Asking about: Desk Lamp'), findsOneWidget);

    await send(tester, 'Is this available?');
    expect(sent.single, {'receiver_id': 7, 'body': 'Is this available?', 'product_id': 42});

    await tester.tap(find.byTooltip('Stop asking about Desk Lamp'));
    await tester.pump();
    expect(find.text('Asking about: Desk Lamp'), findsNothing);

    await send(tester, 'Thanks!');
    expect(sent.last, {'receiver_id': 7, 'body': 'Thanks!'});
    await tester.pumpWidget(const SizedBox()); // stops the page's refresh timer
  });

  testWidgets('a chat opened from the chat list has no product bar', (tester) async {
    await open(tester);
    expect(find.textContaining('Asking about'), findsNothing);

    await send(tester, 'Hello');
    expect(sent.single, {'receiver_id': 7, 'body': 'Hello'});
    await tester.pumpWidget(const SizedBox());
  });
}
