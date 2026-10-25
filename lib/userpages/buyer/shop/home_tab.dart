import 'package:flutter/material.dart';

import '../../../components/components.dart';
import '../../../models/catalog.dart';
import '../../../services/catalog_service.dart';
import '../../../services/recently_viewed_service.dart';
import '../../../services/wishlist_service.dart';
import '../nav.dart';
import '../shop_header.dart';

/// Home: banners, categories, hot discounts, featured, recommended and
/// recently viewed — every section driven by live catalog data.
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final _catalog = CatalogService();
  final _view = GlobalKey<PsAsyncViewState<(HomeFeed, List<Product>)>>();

  Future<(HomeFeed, List<Product>)> _load() async {
    final feed = await _catalog.home();
    WishlistStore.instance.sync([...feed.hotDiscounts, ...feed.featured, ...feed.recommended]);

    // BUY-A06: resolve recently viewed ids against current catalog data.
    final ids = await RecentlyViewed.ids();
    final known = {for (final p in [...feed.recommended, ...feed.featured, ...feed.hotDiscounts]) p.id: p};
    final recent = ids.map((id) => known[id]).whereType<Product>().take(6).toList();
    return (feed, recent);
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
          child: Column(children: [SizedBox(height: PsSpace.md), PsProductGridSkeleton(count: 6)]),
        ),
        isEmpty: (d) => d.$1.recommended.isEmpty && d.$1.hotDiscounts.isEmpty,
        empty: const PsEmptyState(
          icon: Icons.storefront_outlined,
          title: 'No products yet',
          message: 'Sellers haven’t listed anything yet. Pull down to check again.',
        ),
        builder: (context, data, reload) {
          final (feed, recent) = data;
          void open(Product p) => openProduct(context, p.id).then((_) => _view.currentState?.reload());

          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (feed.categories.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: PsSpace.xs, bottom: PsSpace.sm),
                    child: PsFilterChips<String>(
                      selected: '',
                      options: [
                        const PsFilterOption('', 'All Categories'),
                        for (final c in feed.categories) PsFilterOption(c.name, c.name),
                      ],
                      onSelected: (c) => c.isEmpty
                          ? ShellNav.tab.value = BuyerTab.discover
                          : openProductList(context, title: c, category: c),
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: PsBannerCarousel(
                  banners: feed.banners,
                  onTap: (b) {
                    if (b.kind == 'deals') openProductList(context, title: 'Hot Discounts', onSale: true);
                  },
                ),
              ),
              if (feed.hotDiscounts.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: PsSectionHeader(
                    title: 'Hot Discounts',
                    subtitle: 'Biggest markdowns right now',
                    onViewAll: () => openProductList(context, title: 'Hot Discounts', onSale: true),
                  ),
                ),
                PsProductGrid(products: feed.hotDiscounts.take(4).toList(), onTap: open),
              ],
              if (recent.isNotEmpty) ...[
                const SliverToBoxAdapter(child: PsSectionHeader(title: 'Recently Viewed')),
                SliverToBoxAdapter(child: _HorizontalProducts(products: recent, onTap: open)),
              ],
              if (feed.featured.isNotEmpty) ...[
                const SliverToBoxAdapter(child: PsSectionHeader(title: 'Featured Picks', subtitle: 'Hand-picked by the Picksell team')),
                SliverToBoxAdapter(child: _HorizontalProducts(products: feed.featured, onTap: open)),
              ],
              if (feed.recommended.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: PsSectionHeader(
                    title: 'Recommended for You',
                    onViewAll: () => ShellNav.tab.value = BuyerTab.discover,
                  ),
                ),
                PsProductGrid(products: feed.recommended, onTap: open),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: PsSpace.xl)),
            ],
          );
        },
      ),
    );
  }
}

class _HorizontalProducts extends StatelessWidget {
  const _HorizontalProducts({required this.products, required this.onTap});

  final List<Product> products;
  final ValueChanged<Product> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 296,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: PsSpace.page,
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(width: PsSpace.sm),
        itemBuilder: (_, i) => SizedBox(width: 164, child: PsProductCard(product: products[i], onTap: () => onTap(products[i]))),
      ),
    );
  }
}
