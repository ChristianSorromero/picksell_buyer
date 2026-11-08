import 'package:flutter/material.dart';

import '../../../components/components.dart';
import '../../../format_utils.dart';
import '../../../models/catalog.dart';
import '../../../models/chat.dart';
import '../../../services/catalog_service.dart';
import '../../../services/follow_service.dart';
import '../../../services/wishlist_service.dart';
import '../../chats_page.dart';
import '../nav.dart';

/// COM-C04 Seller store: profile, trust signals, follow, chat and the
/// seller's products filtered by category.
class StorePage extends StatefulWidget {
  const StorePage({super.key, required this.sellerId});

  final int sellerId;

  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> {
  final _catalog = CatalogService();
  String _category = '';

  Future<SellerStore> _load() async {
    final s = await _catalog.seller(widget.sellerId);
    WishlistStore.instance.sync(s.products);
    return s;
  }

  @override
  Widget build(BuildContext context) {
    return PsAppShell(
      topBar: const PsTopBar(title: 'Store'),
      body: PsAsyncView<SellerStore>(
        load: _load,
        errorTitle: 'Couldn’t load this store',
        builder: (context, store, _) {
          final s = store.seller;
          final products = _category.isEmpty ? store.products : store.products.where((p) => p.category == _category).toList();
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(PsSpace.gutter),
                  child: PsCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            PsSellerAvatar(name: s.name, size: 72),
                            const SizedBox(width: PsSpace.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Flexible(child: Text(s.name, style: PsText.heading.copyWith(fontSize: 20))),
                                    if (s.verified) ...[const SizedBox(width: 6), const PsTag('VERIFIED', icon: Icons.verified_rounded, color: PsColors.success, background: PsColors.successSoft)],
                                  ]),
                                  if (s.rating != null) PsRatingInline(rating: s.rating, count: s.reviewCount),
                                  if (s.location.isNotEmpty) Text(s.location, style: PsText.caption),
                                  if (s.joinedAt != null) Text('Joined ${formatDate(s.joinedAt!)}', style: PsText.caption),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: PsSpace.md),
                        Row(
                          children: [
                            Expanded(child: _FollowButton(sellerId: s.id, storeName: s.name, following: s.isFollowing, followers: s.followers)),
                            const SizedBox(width: PsSpace.sm),
                            Expanded(
                              child: PsSecondaryButton.outlined(
                                label: 'Chat',
                                icon: Icons.chat_bubble_outline_rounded,
                                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => ChatConversationPage(
                                    contact: ChatContact(id: s.id, name: s.name, initials: s.name.isEmpty ? '?' : s.name[0], lastMessage: ''),
                                  ),
                                )),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (store.categories.length > 1)
                SliverToBoxAdapter(
                  child: PsFilterChips<String>(
                    selected: _category,
                    options: [const PsFilterOption('', 'All products'), for (final c in store.categories) PsFilterOption(c, c)],
                    onSelected: (c) => setState(() => _category = c),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: PsSpace.sm)),
              if (products.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: PsEmptyState(icon: Icons.inventory_2_outlined, title: 'No products listed', message: 'This store has nothing for sale right now.'),
                )
              else
                PsProductGrid(products: products, onTap: (p) => openProduct(context, p.id)),
              const SliverToBoxAdapter(child: SizedBox(height: PsSpace.xl)),
            ],
          );
        },
      ),
    );
  }
}

/// Follow / Following, with the follower count. Flips at once and puts it
/// back if the server refuses; the server's count wins.
class _FollowButton extends StatefulWidget {
  const _FollowButton({required this.sellerId, required this.storeName, required this.following, required this.followers});

  final int sellerId;
  final String storeName;
  final bool following;
  final int followers;

  @override
  State<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<_FollowButton> {
  final _service = FollowService();
  late bool _following = widget.following;
  late int _followers = widget.followers;
  bool _busy = false;

  Future<void> _toggle() async {
    final want = !_following;
    setState(() {
      _busy = true;
      _following = want;
      _followers += want ? 1 : -1;
    });
    try {
      final r = await _service.set(widget.sellerId, follow: want);
      if (!mounted) return;
      setState(() {
        _following = r.following;
        _followers = r.followers;
      });
      PsToast.show(context, want ? 'You are now following ${widget.storeName}.' : 'You unfollowed ${widget.storeName}.');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _following = !want;
        _followers += want ? -1 : 1;
      });
      PsToast.error(context, e.isNetworkError ? 'You’re offline. Try again.' : e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = _followers.clamp(0, 1 << 30);
    final label = '${_following ? 'Following' : 'Follow'}${count > 0 ? ' · $count' : ''}';
    return _following
        ? PsSecondaryButton.outlined(label: label, icon: Icons.check_rounded, onPressed: _busy ? null : _toggle)
        : PsPrimaryButton(label: label, icon: Icons.add_rounded, uppercase: false, onPressed: _busy ? null : _toggle);
  }
}
