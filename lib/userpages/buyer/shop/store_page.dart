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
  final _search = TextEditingController();
  String _category = '';
  ProductSort _sort = ProductSort.newest;

  /// Follower count shown under the rating; the Follow button updates it.
  final _followers = ValueNotifier<int>(0);

  @override
  void dispose() {
    _followers.dispose();
    _search.dispose();
    super.dispose();
  }

  /// The store sends its whole catalog (newest first), so search, category
  /// and sort run here without another request.
  List<Product> _visible(SellerStore store) {
    final q = _search.text.trim().toLowerCase();
    final list = store.products
        .where((p) => _category.isEmpty || p.category == _category)
        .where((p) => q.isEmpty || p.name.toLowerCase().contains(q))
        .toList();
    switch (_sort) {
      case ProductSort.newest:
        break;
      case ProductSort.popular:
        list.sort((a, b) => b.soldCount.compareTo(a.soldCount));
      case ProductSort.rating:
        list.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
      case ProductSort.priceAsc:
        list.sort((a, b) => a.price.compareTo(b.price));
      case ProductSort.priceDesc:
        list.sort((a, b) => b.price.compareTo(a.price));
    }
    return list;
  }

  Future<SellerStore> _load() async {
    final s = await _catalog.seller(widget.sellerId);
    _followers.value = s.seller.followers;
    WishlistStore.instance.sync(s.products);
    return s;
  }

  @override
  Widget build(BuildContext context) {
    return PsAppShell(
      topBar: const PsTopBar(title: 'Store'),
      body: PsAsyncView<SellerStore>(
        load: _load,
        errorTitle: 'This store is unavailable',
        builder: (context, store, _) {
          final s = store.seller;
          final products = _visible(store);
          final narrowed = _category.isNotEmpty || _search.text.trim().isNotEmpty;
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(PsSpace.gutter),
                  child: PsCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // The storefront banner the seller uploaded (website: store page header).
                        if (s.banner != null) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(PsRadius.md),
                            child: AspectRatio(
                              aspectRatio: 3,
                              child: ColoredBox(
                                color: PsColors.surfaceMuted,
                                child: Image.network(
                                  s.banner!,
                                  fit: BoxFit.cover,
                                  semanticLabel: '${s.name} banner',
                                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: PsSpace.md),
                        ],
                        Row(
                          children: [
                            PsSellerAvatar(name: s.name, logo: s.logo, size: 80),
                            const SizedBox(width: PsSpace.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s.name, style: PsText.heading.copyWith(fontSize: 21, height: 1.25), maxLines: 2, overflow: TextOverflow.ellipsis),
                                  if (s.verified) ...[
                                    const SizedBox(height: 6),
                                    PsTag('VERIFIED', icon: Icons.verified_rounded, color: PsColors.success, background: PsColors.successSoft),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: PsSpace.md),
                        // Under the name: ratings & followers on the left,
                        // location & join date on the right.
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: PsSpace.md, vertical: PsSpace.sm),
                          decoration: BoxDecoration(color: PsColors.surfaceMuted, borderRadius: BorderRadius.circular(PsRadius.md)),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _StoreFact(
                                      icon: Icons.star_rounded,
                                      iconColor: PsColors.warning,
                                      text: s.rating == null
                                          ? 'No ratings yet'
                                          : '${s.rating!.toStringAsFixed(1)} (${compactCount(s.reviewCount)} ${s.reviewCount == 1 ? 'rating' : 'ratings'})',
                                    ),
                                    const SizedBox(height: PsSpace.xs),
                                    ValueListenableBuilder<int>(
                                      valueListenable: _followers,
                                      builder: (_, n, __) {
                                        final count = n.clamp(0, 1 << 30);
                                        return _StoreFact(icon: Icons.people_alt_outlined, text: '${compactCount(count)} ${count == 1 ? 'follower' : 'followers'}');
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: PsSpace.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _StoreFact(icon: Icons.location_on_outlined, text: s.location.isEmpty ? 'Location not set' : s.location),
                                    const SizedBox(height: PsSpace.xs),
                                    _StoreFact(icon: Icons.calendar_today_outlined, text: s.joinedAt == null ? 'New on Picksell' : 'Joined ${formatDate(s.joinedAt!)}'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (s.description != null) ...[
                          const SizedBox(height: PsSpace.md),
                          Text(s.description!, style: PsText.body.copyWith(height: 1.5, color: PsColors.textSecondary)),
                        ],
                        const SizedBox(height: PsSpace.md),
                        Row(
                          children: [
                            Expanded(child: _FollowButton(sellerId: s.id, storeName: s.name, following: s.isFollowing, followers: _followers)),
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
              if (store.products.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(PsSpace.gutter, PsSpace.xs, PsSpace.xs, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: PsSearchBar(
                            controller: _search,
                            hint: 'Search this store…',
                            onChanged: (_) => setState(() {}),
                            onSubmitted: (_) => setState(() {}),
                          ),
                        ),
                        PsSortButton<ProductSort>(
                          selected: _sort,
                          options: [for (final o in ProductSort.values) PsFilterOption(o, o.label)],
                          onSelected: (o) => setState(() => _sort = o),
                        ),
                      ],
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: PsSpace.sm)),
              if (products.isEmpty)
                SliverFillRemaining(
                  // The state scrolls itself, so it takes the remaining height as given
                  // (measuring it would throw and blank the screen).
                  hasScrollBody: true,
                  child: narrowed
                      ? PsEmptyState(
                          icon: Icons.search_off_rounded,
                          title: 'No matching products',
                          message: 'This store has nothing that matches. Try another keyword or category.',
                          actionLabel: 'Show all products',
                          onAction: () => setState(() {
                            _search.clear();
                            _category = '';
                          }),
                        )
                      : const PsEmptyState(icon: Icons.inventory_2_outlined, title: 'No products listed', message: 'This store has nothing for sale right now.'),
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

  /// The store's count (shown under its rating); kept in step with a tap.
  final ValueNotifier<int> followers;

  @override
  State<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<_FollowButton> {
  final _service = FollowService();
  late bool _following = widget.following;
  bool _busy = false;

  Future<void> _toggle() async {
    final want = !_following;
    setState(() {
      _busy = true;
      _following = want;
      widget.followers.value += want ? 1 : -1;
    });
    try {
      final r = await _service.set(widget.sellerId, follow: want);
      if (!mounted) return;
      setState(() {
        _following = r.following;
        widget.followers.value = r.followers;
      });
      PsToast.show(context, want ? 'You are now following ${widget.storeName}.' : 'You unfollowed ${widget.storeName}.');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _following = !want;
        widget.followers.value += want ? -1 : 1;
      });
      PsToast.error(context, e.isNetworkError ? 'You’re offline. Try again.' : e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = _following ? 'Following' : 'Follow';
    return _following
        ? PsSecondaryButton.outlined(label: label, icon: Icons.check_rounded, onPressed: _busy ? null : _toggle)
        : PsPrimaryButton(label: label, icon: Icons.add_rounded, uppercase: false, onPressed: _busy ? null : _toggle);
  }
}

/// One line of the store's facts: a small icon and its text.
class _StoreFact extends StatelessWidget {
  const _StoreFact({required this.icon, required this.text, this.iconColor});

  final IconData icon;
  final String text;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 16, color: iconColor ?? PsColors.textMuted),
        ),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: PsText.caption.copyWith(color: PsColors.textPrimary, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}
