import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:picksell/core/network/api_client.dart';
import 'package:picksell/core/network/token_store.dart';
import 'package:picksell/services/auth_service.dart';
import 'package:picksell/services/chat_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await TokenStore.clear();
    ApiClient.sessionExpired.value = 0;
  });

  test('SessionManager stores and retrieves the login token', () async {
    await SessionManager().save(
      token: 'login-token',
      userId: 7,
      name: 'Juan Dela Cruz',
      email: 'juan@example.com',
    );

    expect(await SessionManager().getToken(), 'login-token');
    expect(await SessionManager().getUserId(), 7);
  });

  test('authenticated requests attach the stored Bearer token', () async {
    late http.Request request;
    final client = ApiClient(
      client: MockClient((received) async {
        request = received;
        return http.Response('{}', 200);
      }),
    );
    await TokenStore.write('stored-token');

    await client.getJson('/buyer/profile');

    expect(request.headers['authorization'], 'Bearer stored-token');
  });

  test('requests without a token omit authorization', () async {
    late http.Request request;
    final client = ApiClient(
      client: MockClient((received) async {
        request = received;
        return http.Response('{}', 200);
      }),
    );

    await client.getJson('/home');

    expect(request.headers.containsKey('authorization'), isFalse);
  });

  test('public requests remain usable without a token', () async {
    final client = ApiClient(
      client: MockClient(
        (request) async => http.Response(jsonEncode({'products': []}), 200),
      ),
    );

    expect((await client.getJson('/products'))['products'], isEmpty);
  });

  test('chat uses the shared authenticated client', () async {
    final requests = <http.Request>[];
    await TokenStore.write('chat-token');
    final client = ApiClient(
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/chat/contacts')) {
          return http.Response(jsonEncode({'contacts': []}), 200);
        }
        return http.Response(
          jsonEncode({
            'id': 1,
            'sender_id': 2,
            'receiver_id': 3,
            'body': 'Hello',
            'created_at': '2026-11-02T10:00:00+08:00',
            'is_mine': true,
          }),
          201,
        );
      }),
    );
    final chat = ChatService(client: client);

    await chat.getContacts();
    await chat.sendMessage(3, 'Hello');

    expect(requests, hasLength(2));
    expect(
      requests.every(
        (request) => request.headers['authorization'] == 'Bearer chat-token',
      ),
      isTrue,
    );
    expect(requests.last.headers['content-type'], contains('application/json'));
  });

  test('401 responses notify the app consistently', () async {
    final client = ApiClient(
      client: MockClient(
        (request) async =>
            http.Response(jsonEncode({'message': 'Expired'}), 401),
      ),
    );

    final result = await client.send('GET', '/buyer/profile');

    expect(result.statusCode, 401);
    expect(ApiClient.sessionExpired.value, 1);
  });
}
