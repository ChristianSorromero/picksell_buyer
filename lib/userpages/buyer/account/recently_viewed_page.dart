import 'package:flutter/material.dart';

import '../../../components/components.dart';
import '../../../models/catalog.dart';
import '../../../services/catalog_service.dart';
import '../../../services/recently_viewed_service.dart';
import '../../../services/wishlist_service.dart';
import '../nav.dart';

/// BUY-A06 Recently Viewed — ids stored on-device, products re-fetched so
/// price and stock are current. Products that were removed drop out.
class RecentlyViewedPage extends StatefulWidget {
  const RecentlyViewedPage({super.key});

  @override
  State<RecentlyViewedPage> createState() => _RecentlyViewedPageState();
}

class _RecentlyViewedPageState extends State<RecentlyViewedPage> {
  Key _key = UniqueKey();

  Future<List<Product>> _load() async {
    final catalog = CatalogService();
    final ids = await RecentlyViewed.ids();
    final results = await Future.wait(ids.map((id) async {
      try {
        return (await catalog.product(id)).product;
      } on ApiException catch (e) {
        if (e.isNetworkError) rethrow;
        return null; // unavailable now
      }
    }));
    final products = results.whereType<Product>().toList();
    WishlistStore.instance.sync(products);
    return products;
  }

  @override
  Widget build(BuildContext context) {
    return PsAppShell(
      topBar: PsTopBar(
        title: 'Recently Viewed',
        actions: [
          TextButton(
            onPressed: () async {
              await RecentlyViewed.clear();
              setState(() => _key = UniqueKey());
            },
            child: const Text('Clear'),
          ),
        ],
      ),
      body: PsAsyncView<List<Product>>(
        key: _key,
        load: _load,
        loading: const SingleChildScrollView(child: PsProductGridSkeleton()),
        isEmpty: (l) => l.isEmpty,
        empty: const PsEmptyState(icon: Icons.history_rounded, title: 'Nothing viewed yet', message: 'Products you open will appear here.'),
        builder: (context, list, _) => CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: PsSpace.md)),
            PsProductGrid(products: list, onTap: (p) => openProduct(context, p.id)),
            const SliverToBoxAdapter(child: SizedBox(height: PsSpace.xl)),
          ],
        ),
      ),
    );
  }
}
