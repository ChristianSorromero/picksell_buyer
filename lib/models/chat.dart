import 'json.dart';

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
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        initials: json['initials'] as String? ?? '?',
        lastMessage: json['last_message'] as String? ?? '',
        lastTime: toDate(json['last_time']),
        unread: json['unread'] as int? ?? 0,
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

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as int,
        body: json['body'] as String,
        senderId: json['sender_id'] as int,
        createdAt: toDate(json['created_at']) ?? DateTime.now(),
        isMine: json['is_mine'] as bool,
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
