import '../core/network/api_client.dart';
import '../models/chat.dart';

class ChatService {
  ChatService({ApiClient? client}) : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  Future<List<ChatContact>> getContacts() async {
    final data = await _api.getJson('/chat/contacts');
    return (data['contacts'] as List? ?? const [])
        .map((e) => ChatContact.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<ChatMessage>> getMessages(int userId) async {
    final data = await _api.getJson('/chat/messages/$userId');
    return (data['messages'] as List? ?? const [])
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ChatMessage> sendMessage(int receiverId, String body) async =>
      ChatMessage.fromJson(
        await _api.postJson('/chat/send', {
          'receiver_id': receiverId,
          'body': body,
        }),
      );
}
