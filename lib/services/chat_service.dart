import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import '../models/chat.dart';

class ChatService {
  Future<Map<String, String>> _headers() async {
    final token = await SessionManager().getToken();
    return {
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
      'ngrok-skip-browser-warning': 'true',
    };
  }

  Future<List<ChatContact>> getContacts() async {
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/chat/contacts'),
        headers: await _headers(),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return (data['contacts'] as List)
            .map((e) => ChatContact.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<ChatMessage>> getMessages(int userId) async {
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/chat/messages/$userId'),
        headers: await _headers(),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return (data['messages'] as List)
            .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<ChatMessage?> sendMessage(int receiverId, String body) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/chat/send'),
        headers: {...await _headers(), 'Content-Type': 'application/json'},
        body: jsonEncode({'receiver_id': receiverId, 'body': body}),
      );
      if (res.statusCode == 201) {
        return ChatMessage.fromJson(
            jsonDecode(res.body) as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }
}
