import 'package:flutter/material.dart';

import '../../../components/components.dart';
import '../../../format_utils.dart';
import '../../../models/catalog.dart';
import '../../../models/chat.dart';
import '../../../services/catalog_service.dart';
import '../../../services/wishlist_service.dart';
import '../../chats_page.dart';
import '../nav.dart';

/// COM-C04 Seller store: profile, trust signals, chat and the seller's
/// products filtered by category.
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
                        PsSecondaryButton.outlined(
                          label: 'Chat with seller',
                          icon: Icons.chat_bubble_outline_rounded,
                          expand: true,
                          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => ChatConversationPage(
                              contact: ChatContact(id: s.id, name: s.name, initials: s.name.isEmpty ? '?' : s.name[0], lastMessage: ''),
                            ),
                          )),
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
