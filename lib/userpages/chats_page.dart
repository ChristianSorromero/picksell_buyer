import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app_colors.dart';
import '../app_text_styles.dart';
import '../models/chat.dart';
import '../services/chat_service.dart';

const List<Color> _avatarTints = [
  AppColors.tileYellow,
  AppColors.tileMint,
  AppColors.tileRose,
  AppColors.tileCream,
  AppColors.tileGrey,
];

// ─────────────────────────── CONTACTS LIST ───────────────────────────

class ChatsPage extends StatefulWidget {
  const ChatsPage({super.key});

  @override
  State<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends State<ChatsPage> {
  final _service = ChatService();
  List<ChatContact> _contacts = [];
  bool _loading = true;
  String _query = '';
  bool _searching = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final contacts = await _service.getContacts();
    if (mounted) setState(() { _contacts = contacts; _loading = false; });
  }

  List<ChatContact> get _visible {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _contacts;
    return _contacts.where((c) => c.name.toLowerCase().contains(q) || c.lastMessage.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            if (_searching) _buildSearchField(),
            const SizedBox(height: 8),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 20, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            color: AppColors.textPrimary,
          ),
          Text('Chats', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() {
              _searching = !_searching;
              if (!_searching) { _query = ''; _searchController.clear(); }
            }),
            child: Icon(_searching ? Icons.close_rounded : Icons.search_rounded, size: 22, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        onChanged: (v) => setState(() => _query = v),
        style: AppTextStyles.input,
        cursorColor: AppColors.primary,
        decoration: InputDecoration(
          hintText: 'Search chats',
          hintStyle: AppTextStyles.hint,
          filled: true,
          fillColor: AppColors.inputFill,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.textSecondary),
          prefixIconConstraints: const BoxConstraints(minWidth: 44),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final contacts = _visible;
    if (contacts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chat_bubble_outline_rounded, size: 48, color: AppColors.textHint),
            const SizedBox(height: 12),
            Text('No conversations yet', style: AppTextStyles.body),
            const SizedBox(height: 4),
            Text('Start a chat from a product page', style: AppTextStyles.small),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        itemCount: contacts.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
        itemBuilder: (_, i) => _ContactTile(
          contact: contacts[i],
          tint: _avatarTints[i % _avatarTints.length],
          onTap: () async {
            await Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ChatConversationPage(contact: contacts[i]),
            ));
            _load(); // refresh unread counts on return
          },
        ),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.contact, required this.tint, required this.onTap});
  final ChatContact contact;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 52, height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
              child: Text(contact.initials, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(contact.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  const SizedBox(height: 3),
                  Text(contact.lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.small.copyWith(
                        fontWeight: contact.hasUnread ? FontWeight.w500 : FontWeight.w400,
                        color: contact.hasUnread ? AppColors.textPrimary : AppColors.textSecondary,
                      )),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(contact.timeLabel, style: AppTextStyles.caption.copyWith(letterSpacing: 0, fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                if (contact.hasUnread)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    alignment: Alignment.center,
                    child: Text('${contact.unread}', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── CONVERSATION ───────────────────────────

class ChatConversationPage extends StatefulWidget {
  const ChatConversationPage({super.key, required this.contact});
  final ChatContact contact;

  @override
  State<ChatConversationPage> createState() => _ChatConversationPageState();
}

class _ChatConversationPageState extends State<ChatConversationPage> {
  final _service = ChatService();
  final _scrollController = ScrollController();
  final _inputController = TextEditingController();
  List<ChatMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _pollMessages());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _scrollController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() => _loading = true);
    final msgs = await _service.getMessages(widget.contact.id);
    if (mounted) {
      setState(() { _messages = msgs; _loading = false; });
      _scrollToBottom();
    }
  }

  Future<void> _pollMessages() async {
    final msgs = await _service.getMessages(widget.contact.id);
    if (mounted && msgs.length != _messages.length) {
      setState(() => _messages = msgs);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final body = _inputController.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    _inputController.clear();
    final msg = await _service.sendMessage(widget.contact.id, body);
    if (mounted) {
      if (msg != null) setState(() => _messages.add(msg));
      setState(() => _sending = false);
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              width: 36, height: 36,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: AppColors.tileYellow, shape: BoxShape.circle),
              child: Text(widget.contact.initials, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(widget.contact.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(child: Text('No messages yet. Start the conversation!', style: AppTextStyles.small, textAlign: TextAlign.center))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) => _MessageBubble(message: _messages[i]),
                      ),
          ),
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              style: AppTextStyles.input,
              cursorColor: AppColors.primary,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: AppTextStyles.hint,
                filled: true,
                fillColor: AppColors.inputFill,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _send,
            child: Container(
              width: 44, height: 44,
              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              child: _sending
                  ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isMine = message.isMine;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isMine ? AppColors.primary : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isMine ? 18 : 4),
                bottomRight: Radius.circular(isMine ? 4 : 18),
              ),
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 4, offset: const Offset(0, 1))],
            ),
            child: Text(message.body,
                style: GoogleFonts.inter(fontSize: 14, color: isMine ? Colors.white : AppColors.textPrimary)),
          ),
          const SizedBox(height: 3),
          Text(
            '${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}',
            style: AppTextStyles.caption.copyWith(fontSize: 10, letterSpacing: 0),
          ),
        ],
      ),
    );
  }
}
