import '../core/network/api_client.dart';
import '../models/chat.dart';

class ChatService {
  ChatService({ApiClient? client}) : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  Future<List<ChatContact>> getContacts() async {
    final data = await _api.getJson('/chat/contacts');
    return (data['contacts'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ChatContact.fromJson)
        .where((c) => c.id > 0)
        .toList();
  }

  Future<List<ChatMessage>> getMessages(int userId) async {
    final data = await _api.getJson('/chat/messages/$userId');
    return (data['messages'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ChatMessage.fromJson)
        .toList();
  }

  /// [productId] tags the message with the product the buyer is asking about, as the website's
  /// "Asking about" bar does.
  Future<ChatMessage> sendMessage(int receiverId, String body, {int? productId}) async =>
      ChatMessage.fromJson(
        await _api.postJson('/chat/send', {
          'receiver_id': receiverId,
          'body': body,
          if (productId != null) 'product_id': productId,
        }),
      );
}
