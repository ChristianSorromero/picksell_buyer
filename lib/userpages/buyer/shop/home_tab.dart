import 'dart:async';

import 'package:flutter/material.dart';

import '../../../components/components.dart';
import '../../../models/catalog.dart';
import '../../../models/order.dart';
import '../../../services/catalog_service.dart';
import '../../../services/order_service.dart';
import '../../../services/wishlist_service.dart';
import '../account/following_page.dart';
import '../account/my_picks_page.dart';
import '../nav.dart';
import '../shop_header.dart';

/// Home: banners, categories, then short sideways rows (hot discounts,
/// featured, recently viewed) and an endless "Recommended for you" feed —
/// every section driven by live catalog data.
///
/// The feed is the website's product list (GET /products, newest first, the
/// same order as the website's "Recommended"), loaded a page at a time as the
/// buyer nears the bottom.
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final _catalog = CatalogService();
  final _view = GlobalKey<PsAsyncViewState<(HomeFeed, List<Product>)>>();

  /// "Recommended for you": every page loaded so far, without repeats.
  final List<Product> _feed = [];
  final Set<int> _feedIds = {};
  PageMeta _meta = const PageMeta();
  bool _loadingMore = false;
  bool _moreFailed = false;

  /// The newest order still on its way, for the "Arriving today" card.
  OrderSummaryItem? _active;

  Future<void> _loadActiveOrder() async {
    try {
      final list = await OrderService().list();
      final open = list.orders.where((o) =>
          !o.status.isFinal && !o.status.isException && o.tab != OrderTab.toRate && o.tab != OrderTab.completed);
      if (mounted) setState(() => _active = open.isEmpty ? null : open.first);
    } catch (_) {
      // The card is optional; Home works without it.
    }
  }

  void _addToFeed(ProductPage page) {
    for (final p in page.products) {
      if (_feedIds.add(p.id)) _feed.add(p);
    }
    _meta = page.meta;
  }

  Future<(HomeFeed, List<Product>)> _load() async {
    unawaited(_loadActiveOrder());
    final results = await Future.wait([_catalog.home(), _catalog.products()]);
    final feed = results[0] as HomeFeed;
    final first = results[1] as ProductPage;
    _feed.clear();
    _feedIds.clear();
    _moreFailed = false;
    _addToFeed(first);
    WishlistStore.instance.sync([
      ...feed.hotDiscounts,
      ...feed.featured,
      ...feed.recentlyViewed,
      ...first.products,
    ]);

    // BUY-A06: the server's list, shared with the website.
    return (feed, feed.recentlyViewed.take(10).toList());
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_meta.hasMore) return;
    setState(() {
      _loadingMore = true;
      _moreFailed = false;
    });
    try {
      final page = await _catalog.products(page: _meta.currentPage + 1);
      WishlistStore.instance.sync(page.products);
      if (mounted) setState(() => _addToFeed(page));
    } catch (_) {
      if (mounted) setState(() => _moreFailed = true);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  bool _onScroll(ScrollNotification n) {
    // Start the next page well before the end, so scrolling never hits a wall.
    if (n.metrics.axis == Axis.vertical && n.metrics.extentAfter < 900 && !_moreFailed) _loadMore();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PsAppShell(
      topBar: const ShopHeader(),
      body: PsAsyncView<(HomeFeed, List<Product>)>(
        key: _view,
        load: _load,
        loading: const SingleChildScrollView(
          physics: NeverScrollableScrollPhysics(),
          child: Column(
            children: [
              SizedBox(height: PsSpace.md),
              PsProductGridSkeleton(count: 6),
            ],
          ),
        ),
        isEmpty: (d) => _feed.isEmpty && d.$1.hotDiscounts.isEmpty,
        empty: const PsEmptyState(
          icon: Icons.storefront_outlined,
          title: 'No products yet',
          message: 'Sellers haven’t listed anything yet. Pull down to check again.',
        ),
        builder: (context, data, reload) {
          final (feed, recent) = data;
          void open(Product p) => openProduct(context, p.id).then((_) => _view.currentState?.reload());

          // Same order as the website's menu.
          final categories = [for (final c in feed.categories) c.name];
          final discounts = feed.hotDiscounts.map((p) => p.discountPercent ?? 0).where((d) => d > 0);
          void push(Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
          void deals() => openProductList(context, title: 'Hot Discounts', onSale: true);

          return NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (categories.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _CategoryChips(
                      categories: categories,
                      onAll: () => ShellNav.tab.value = BuyerTab.discover,
                      onCategory: (c) => openProductList(context, title: c, category: c),
                    ),
                  ),
                if (_active != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(PsSpace.gutter, PsSpace.sm, PsSpace.gutter, 0),
                      child: PsActiveOrderCard(order: _active!, onTap: () => openOrder(context, _active!.id).then((_) => _loadActiveOrder())),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: PsSpace.md)),
                SliverToBoxAdapter(
                  child: PsBentoHero(
                    banners: feed.banners,
                    onBanner: (b) {
                      if (b.kind == 'deals') deals();
                    },
                    topDiscount: discounts.isEmpty ? null : discounts.reduce((a, b) => a > b ? a : b),
                    onDeals: deals,
                    onPicks: () => push(const MyPicksPage()),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: PsSpace.md),
                    child: PsQuickActions(actions: [
                      ('My Picks', Icons.favorite_border_rounded, false, () => push(const MyPicksPage())),
                      ('Orders', Icons.inventory_2_outlined, false, () => openOrders(context)),
                      ('Following', Icons.storefront_outlined, false, () => push(const FollowingPage())),
                      ('Deals', Icons.bolt_rounded, true, deals),
                    ]),
                  ),
                ),
                if (feed.hotDiscounts.isNotEmpty || feed.featured.isNotEmpty || recent.isNotEmpty)
                  SliverToBoxAdapter(
                    child: PsTintedPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (feed.hotDiscounts.isNotEmpty) ...[
                            PsSectionHeader(
                              title: 'Hot Discounts',
                              subtitle: 'Biggest markdowns right now',
                              padding: const EdgeInsets.fromLTRB(PsSpace.gutter, 22, PsSpace.gutter, 10),
                              onViewAll: deals,
                            ),
                            _HorizontalProducts(products: feed.hotDiscounts, onTap: open),
                          ],
                          if (feed.featured.isNotEmpty) ...[
                            const PsSectionHeader(title: 'Featured Picks', subtitle: 'Hand-picked by the Picksell team'),
                            _HorizontalProducts(products: feed.featured, onTap: open),
                          ],
                          if (recent.isNotEmpty) ...[
                            const PsSectionHeader(title: 'Recently Viewed'),
                            _HorizontalProducts(products: recent, onTap: open),
                          ],
                        ],
                      ),
                    ),
                  ),
                if (_feed.isNotEmpty) ...[
                  const SliverToBoxAdapter(
                    child: PsSectionHeader(title: 'Picked for you', subtitle: 'Fresh from PickSell sellers'),
                  ),
                  PsProductGrid(products: _feed, onTap: open),
                ],
                SliverToBoxAdapter(child: _feedFooter()),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _feedFooter() {
    final Widget child;
    if (_loadingMore) {
      child = SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2.4, color: PsColors.primary));
    } else if (_moreFailed) {
      child = TextButton.icon(
        onPressed: _loadMore,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Couldn’t load more. Tap to retry'),
      );
    } else if (!_meta.hasMore && _feed.isNotEmpty) {
      child = Text('You’ve seen everything for now', style: PsText.caption);
    } else {
      child = const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(PsSpace.gutter, PsSpace.lg, PsSpace.gutter, PsSpace.xl),
      child: Center(child: child),
    );
  }
}

/// A sideways row of cards (hot discounts, featured, recently viewed).
class _HorizontalProducts extends StatelessWidget {
  const _HorizontalProducts({required this.products, required this.onTap});

  final List<Product> products;
  final ValueChanged<Product> onTap;

  static const double _cardWidth = 156;

  @override
  Widget build(BuildContext context) {
    // Every card is the same width and height; the card lays its content out
    // inside (see PsProductCard.uniform). Height fits photo + two-line name +
    // price + stars/sold + low-stock note + store, and grows with the
    // phone's text size setting.
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final height = _cardWidth + 150 * textScale;
    return SizedBox(
      height: height + 12,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(PsSpace.gutter, 2, PsSpace.gutter, 10),
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => SizedBox(
          width: _cardWidth,
          height: height,
          child: PsProductCard(product: products[i], uniform: true, onTap: () => onTap(products[i])),
        ),
      ),
    );
  }
}

/// Category pills under the search bar: "All" (dark, Coral dot) opens
/// Discover; each category opens its product list.
class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.categories, required this.onAll, required this.onCategory});

  final List<String> categories;
  final VoidCallback onAll;
  final ValueChanged<String> onCategory;

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, VoidCallback onTap, {bool first = false}) {
      final fg = first ? PsColors.surface : PsColors.textPrimary;
      return Semantics(
        button: true,
        label: first ? 'All categories' : label,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(PsRadius.pill),
          child: Center(
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: first ? PsColors.textPrimary : PsColors.surface,
                borderRadius: BorderRadius.circular(PsRadius.pill),
                border: Border.all(color: first ? PsColors.textPrimary : PsColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (first) ...[
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: PsColors.primary, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                  ],
                  Text(label, style: PsText.ui.copyWith(color: fg)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: PsSize.minTap + 8,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(PsSpace.gutter, 4, PsSpace.gutter, 4),
        itemCount: categories.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: PsSpace.xs),
        itemBuilder: (_, i) => i == 0 ? chip('All', onAll, first: true) : chip(categories[i - 1], () => onCategory(categories[i - 1])),
      ),
    );
  }
}
