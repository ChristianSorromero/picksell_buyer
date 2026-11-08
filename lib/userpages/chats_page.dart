import 'dart:async';
import 'package:flutter/material.dart';

import '../components/shared/ps_app_shell.dart';
import '../components/shared/ps_buttons.dart';
import '../components/shared/ps_search_bar.dart';
import '../components/shared/ps_top_bar.dart';
import '../components/shared/states/ps_empty_state.dart';
import '../core/network/api_client.dart';
import '../core/theme/ps_colors.dart';
import '../core/theme/ps_tokens.dart';
import '../core/theme/ps_typography.dart';
import '../models/chat.dart';
import '../services/chat_service.dart';

/// Soft token washes for contact avatars, picked by contact id so a contact
/// keeps the same color in the list, while searching and in the thread.
const List<Color> _avatarTints = [
  PsColors.primarySoft,
  PsColors.infoSoft,
  PsColors.successSoft,
  PsColors.warningSoft,
  PsColors.neutralSoft,
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
    try {
      final contacts = await _service.getContacts();
      if (mounted) setState(() => _contacts = contacts);
    } on ApiException catch (e) {
      if (mounted) _showError(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  List<ChatContact> get _visible {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _contacts;
    return _contacts.where((c) => c.name.toLowerCase().contains(q) || c.lastMessage.toLowerCase().contains(q)).toList();
  }

  void _toggleSearch() => setState(() {
        _searching = !_searching;
        if (!_searching) { _query = ''; _searchController.clear(); }
      });

  @override
  Widget build(BuildContext context) {
    return PsAppShell(
      topBar: PsTopBar(
        title: 'Chats',
        actions: [
          PsIconButton(
            icon: _searching ? Icons.close_rounded : Icons.search_rounded,
            tooltip: _searching ? 'Close search' : 'Search chats',
            onPressed: _toggleSearch,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_searching)
            Padding(
              padding: const EdgeInsets.fromLTRB(PsSpace.gutter, 0, PsSpace.gutter, PsSpace.xs),
              child: PsSearchBar(
                hint: 'Search chats',
                controller: _searchController,
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final contacts = _visible;
    if (contacts.isEmpty) {
      return _query.trim().isEmpty
          ? const PsEmptyState(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'No conversations yet',
              message: 'Start a chat from a product page',
            )
          : PsEmptyState(
              icon: Icons.search_off_rounded,
              title: 'No matching chats',
              message: 'Nothing matches “${_query.trim()}”.',
            );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: PsColors.primaryStrong,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(PsSpace.gutter, 0, PsSpace.gutter, PsSpace.lg),
        itemCount: contacts.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: _ContactTile.textInset),
        itemBuilder: (_, i) => _ContactTile(
          contact: contacts[i],
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

/// Initials on a soft token wash; same tint wherever the contact appears.
class _ChatAvatar extends StatelessWidget {
  const _ChatAvatar({required this.contact, this.size = 48});
  final ChatContact contact;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size, height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: _avatarTints[contact.id % _avatarTints.length], shape: BoxShape.circle),
        child: Text(contact.initials, style: PsText.bodyStrong.copyWith(fontSize: size * 0.32)),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.contact, required this.onTap});
  final ChatContact contact;
  final VoidCallback onTap;

  /// Divider indent: lines up with the name, past the avatar.
  static const double textInset = 48 + PsSpace.sm;

  @override
  Widget build(BuildContext context) {
    final unread = contact.hasUnread;
    return Semantics(
      button: true,
      label: [
        contact.name,
        if (unread) '${contact.unread} unread',
        contact.lastMessagePreview,
        contact.timeLabel,
      ].where((s) => s.isNotEmpty).join(', '),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: PsRadius.card,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: PsSpace.sm),
          child: Row(
            children: [
              _ChatAvatar(contact: contact),
              const SizedBox(width: PsSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(contact.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: PsText.bodyStrong),
                    const SizedBox(height: 2),
                    Text(contact.lastMessagePreview, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: unread
                            ? PsText.body.copyWith(fontSize: 13.5, fontWeight: FontWeight.w600)
                            : PsText.bodyMuted),
                  ],
                ),
              ),
              const SizedBox(width: PsSpace.xs),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(contact.timeLabel,
                      style: PsText.caption.copyWith(
                        fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                        color: unread ? PsColors.primaryStrong : PsColors.textMuted,
                      )),
                  const SizedBox(height: 6),
                  if (unread)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: PsColors.primary, borderRadius: BorderRadius.circular(PsRadius.pill)),
                      child: Text(contact.unread > 99 ? '99+' : '${contact.unread}',
                          style: PsText.badge.copyWith(letterSpacing: 0, color: PsColors.onPrimary)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── CONVERSATION ───────────────────────────

class ChatConversationPage extends StatefulWidget {
  const ChatConversationPage({super.key, required this.contact, this.productId, this.productName});
  final ChatContact contact;

  /// Opened from a product: messages say which product they are about until the buyer clears it.
  final int? productId;
  final String? productName;

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
  late int? _productId = widget.productId;

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
    try {
      final msgs = await _service.getMessages(widget.contact.id);
      if (mounted) {
        setState(() => _messages = msgs);
        _scrollToBottom();
      }
    } on ApiException catch (e) {
      if (mounted) _showError(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pollMessages() async {
    try {
      final msgs = await _service.getMessages(widget.contact.id);
      if (mounted && msgs.length != _messages.length) {
        setState(() => _messages = msgs);
        _scrollToBottom();
      }
    } on ApiException catch (e) {
      if (mounted) _showError(e.message);
    }
  }

  void _showError(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

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
    try {
      final msg = await _service.sendMessage(widget.contact.id, body, productId: _productId);
      if (mounted) {
        setState(() => _messages.add(msg));
        _scrollToBottom();
      }
    } on ApiException catch (e) {
      if (mounted) _showError(e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PsAppShell(
      topBar: PsTopBar(
        titleWidget: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ChatAvatar(contact: widget.contact, size: 36),
            const SizedBox(width: PsSpace.xs),
            Flexible(
              child: Text(widget.contact.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: PsText.heading.copyWith(fontSize: 16)),
            ),
          ],
        ),
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _messages.isEmpty
              ? const PsEmptyState(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'No messages yet',
                  message: 'Say hello to start the conversation.',
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: PsSpace.gutter, vertical: PsSpace.sm),
                  itemCount: _messages.length,
                  itemBuilder: (_, i) => _MessageBubble(message: _messages[i]),
                ),
      footer: _buildInput(),
    );
  }

  Widget _buildInput() {
    return Container(
      decoration: const BoxDecoration(
        color: PsColors.surface,
        border: Border(top: BorderSide(color: PsColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_productId != null) _askingAbout(),
          Padding(
          padding: const EdgeInsets.fromLTRB(PsSpace.gutter, PsSpace.xs, PsSpace.xs, PsSpace.xs),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputController,
                  style: PsText.input,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: 'Type a message…',
                    hintStyle: PsText.hint,
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(PsRadius.pill),
                      borderSide: const BorderSide(color: PsColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(PsRadius.pill),
                      borderSide: const BorderSide(color: PsColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(PsRadius.pill),
                      borderSide: const BorderSide(color: PsColors.primary, width: 1.4),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: PsSpace.xxs),
              Tooltip(
                message: 'Send message',
                child: Material(
                  type: MaterialType.transparency,
                  child: InkResponse(
                    onTap: _send,
                    radius: PsSize.minTap / 2 + 2,
                    child: SizedBox.square(
                      dimension: PsSize.minTap + 4,
                      child: Center(
                        child: Container(
                          width: PsSize.minTap, height: PsSize.minTap,
                          decoration: const BoxDecoration(color: PsColors.primary, shape: BoxShape.circle),
                          child: _sending
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(strokeWidth: 2, color: PsColors.onPrimary),
                                )
                              : const Icon(Icons.send_rounded, color: PsColors.onPrimary, size: 20),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        ]),
      ),
    );
  }

  /// The website's "Asking about: [product]" bar, with a button to stop asking about it.
  Widget _askingAbout() => Container(
        width: double.infinity,
        color: PsColors.background,
        padding: const EdgeInsets.fromLTRB(PsSpace.gutter, 2, 0, 2),
        child: Row(
          children: [
            const Icon(Icons.shopping_bag_outlined, size: 16, color: PsColors.textSecondary),
            const SizedBox(width: PsSpace.xxs),
            Expanded(
              child: Text.rich(
                TextSpan(text: 'Asking about: ', children: [
                  TextSpan(text: widget.productName ?? 'this product', style: const TextStyle(fontWeight: FontWeight.w700)),
                ]),
                style: PsText.caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              tooltip: 'Stop asking about ${widget.productName ?? 'this product'}',
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: () => setState(() => _productId = null),
            ),
          ],
        ),
      );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isMine = message.isMine;
    const corner = Radius.circular(PsRadius.lg);
    const tail = Radius.circular(PsSpace.xxs);
    return Padding(
      padding: const EdgeInsets.only(bottom: PsSpace.xs),
      child: Column(
        crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              // Dark onPrimary text keeps the coral bubble readable (~6:1). Automatic replies sit
              // on a muted wash so they don't pass for a message the seller typed.
              color: isMine ? PsColors.primary : (message.isAutoReply ? PsColors.surfaceMuted : PsColors.surface),
              border: isMine ? null : Border.all(color: PsColors.border),
              borderRadius: BorderRadius.only(
                topLeft: corner,
                topRight: corner,
                bottomLeft: isMine ? corner : tail,
                bottomRight: isMine ? tail : corner,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.isAutoReply)
                  Padding(
                    padding: const EdgeInsets.only(bottom: PsSpace.xxs),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.smart_toy_outlined, size: 14, color: PsColors.textMuted),
                        const SizedBox(width: PsSpace.xxs),
                        Text('Automatic reply', style: PsText.caption.copyWith(fontSize: 11.5, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                Text(message.displayBody, style: PsText.body.copyWith(color: isMine ? PsColors.onPrimary : PsColors.textPrimary)),
              ],
            ),
          ),
          const SizedBox(height: PsSpace.xxs),
          Text(
            '${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}',
            style: PsText.caption.copyWith(fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}
