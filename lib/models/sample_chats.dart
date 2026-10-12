import 'chat.dart';

/// Hardcoded chats used until messaging is connected to the backend.
const List<Chat> sampleChats = [
  Chat(
    id: 1,
    sellerName: 'Studio Pottery Co.',
    lastMessage: 'Yes, the speckled clay mug is back in stock!',
    timeLabel: '10:32 AM',
    unreadCount: 2,
    isActive: true,
  ),
  Chat(
    id: 2,
    sellerName: 'Marcus Woodworks',
    lastMessage: 'The custom oak coffee table is ready for pickup.',
    timeLabel: 'Yesterday',
    unreadCount: 1,
    isActive: true,
  ),
  Chat(
    id: 3,
    sellerName: 'Linen & Thread',
    lastMessage: 'Sent you the tracking link for your order.',
    timeLabel: '2 days ago',
  ),
  Chat(
    id: 4,
    sellerName: 'Lumina Glass',
    lastMessage: 'Perfect! Hope you enjoy your new vase.',
    timeLabel: '5 days ago',
  ),
  Chat(
    id: 5,
    sellerName: 'Dainty Gems Jewelry',
    lastMessage: 'We can customize the gold ring size for you.',
    timeLabel: '1 week ago',
  ),
];
