import 'package:flutter/widgets.dart' show StringCharacters;

import 'json.dart';

/// Starts every message the server sends on a seller's behalf (thank-you and vacation away
/// replies; Picksell's Message::AUTO_REPLY_PREFIX).
const String autoReplyPrefix = '[Auto-reply]';

/// The server's initials, or the first letter of the name when it sent none.
String _initials(String? given, String? name) {
  final g = given?.trim() ?? '';
  if (g.isNotEmpty) return g;
  final n = name?.trim() ?? '';
  return n.isEmpty ? '?' : n.characters.first.toUpperCase();
}

bool _isAutoReply(String body) => body.startsWith(autoReplyPrefix);

String _withoutPrefix(String body) => body.substring(autoReplyPrefix.length).trimLeft();

class ChatContact {
  const ChatContact({
    required this.id,
    required this.name,
    required this.initials,
    required this.lastMessage,
    this.lastTime,
    this.unread = 0,
  });

  final int id;
  final String name;
  final String initials;
  final String lastMessage;
  final DateTime? lastTime;
  final int unread;

  bool get hasUnread => unread > 0;

  /// Contact-list preview; an automatic reply is labelled so it isn't read as the seller typing.
  String get lastMessagePreview => _isAutoReply(lastMessage) ? 'Auto-reply: ${_withoutPrefix(lastMessage)}' : lastMessage;

  String get timeLabel {
    final t = lastTime;
    if (t == null) return '';
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    if (diff.inDays == 1) return 'Yesterday';
    return '${t.month}/${t.day}';
  }

  factory ChatContact.fromJson(Map<String, dynamic> json) => ChatContact(
        // Read loosely: one odd contact must never take the whole Messages page down.
        id: toInt(json['id']),
        name: toStr(json['name']) ?? '',
        initials: _initials(toStr(json['initials']), toStr(json['name'])),
        lastMessage: toStr(json['last_message']) ?? '',
        lastTime: toDate(json['last_time']),
        unread: toInt(json['unread']),
      );
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.body,
    required this.senderId,
    required this.createdAt,
    required this.isMine,
  });

  final int id;
  final String body;
  final int senderId;
  final DateTime createdAt;
  final bool isMine;

  /// Sent automatically on the seller's behalf, not typed by them.
  bool get isAutoReply => !isMine && _isAutoReply(body);

  /// [body] without the server's auto-reply marker.
  String get displayBody => isAutoReply ? _withoutPrefix(body) : body;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: toInt(json['id']),
        body: toStr(json['body']) ?? '',
        senderId: toInt(json['sender_id']),
        createdAt: toDate(json['created_at']) ?? DateTime.now(),
        isMine: json['is_mine'] == true,
      );
}

// Keep old Chat class for any remaining references
class Chat {
  const Chat({
    required this.id,
    required this.sellerName,
    required this.lastMessage,
    required this.timeLabel,
    this.unreadCount = 0,
    this.isActive = false,
  });
  final int id;
  final String sellerName;
  final String lastMessage;
  final String timeLabel;
  final int unreadCount;
  final bool isActive;
  bool get hasUnread => unreadCount > 0;
}
