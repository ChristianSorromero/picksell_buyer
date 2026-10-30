import 'package:flutter/material.dart';

import '../../../components/components.dart';
import '../../../models/catalog.dart';
import '../../../services/recently_viewed_service.dart';
import '../../../services/wishlist_service.dart';
import '../nav.dart';

/// BUY-A06 Recently Viewed — the same list as the website's "Recently
/// Viewed" row. Products that can no longer be bought drop out.
class RecentlyViewedPage extends StatefulWidget {
  const RecentlyViewedPage({super.key});

  @override
  State<RecentlyViewedPage> createState() => _RecentlyViewedPageState();
}

class _RecentlyViewedPageState extends State<RecentlyViewedPage> {
  final _service = RecentlyViewedService();
  Key _key = UniqueKey();

  Future<List<Product>> _load() async {
    final products = await _service.list();
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
              await _service.clear();
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
