import 'package:flutter/material.dart';

import '../../../components/components.dart';
import '../../../models/catalog.dart';
import '../../../services/cart_service.dart';
import '../../../services/catalog_service.dart';
import '../../../services/wishlist_service.dart';
import '../nav.dart';

enum _PicksFilter { all, onSale, available }

/// BUY-A05 My Picks — saved products with "Move to cart".
class MyPicksPage extends StatefulWidget {
  const MyPicksPage({super.key});

  @override
  State<MyPicksPage> createState() => _MyPicksPageState();
}

class _MyPicksPageState extends State<MyPicksPage> {
  final _store = WishlistStore.instance;
  _PicksFilter _filter = _PicksFilter.all;

  Future<void> _moveToCart(Product p) async {
    ProductDetail detail;
    try {
      detail = await CatalogService().product(p.id);
    } catch (e) {
      if (mounted) PsToast.error(context, errorMessage(e));
      return;
    }
    if (!mounted) return;
    final ok = await PsProductConfigSheet.show(
      context,
      detail: detail,
      actionLabel: 'Add to cart',
      onSubmit: (s) => CartStore.instance.add(detail.product, quantity: s.quantity, variationIds: s.variationIds),
    );
    if (!ok || !mounted) return;
    try {
      await _store.toggle(p.id);
    } catch (_) {}
    if (mounted) {
      PsToast.show(context, '${p.name} moved to cart', type: PsToastType.success, actionLabel: 'View Cart', onAction: () => ShellNav.goTo(context, BuyerTab.cart));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PsAppShell(
      topBar: const PsTopBar(title: 'My Picks'),
      body: PsAsyncView<List<Product>>(
        load: _store.load,
        isEmpty: (l) => l.isEmpty,
        empty: PsEmptyState(
          icon: Icons.favorite_border_rounded,
          title: 'No saved items yet',
          message: 'Tap the heart on any product to save it here.',
          actionLabel: 'Browse products',
          onAction: () => ShellNav.goTo(context, BuyerTab.discover),
        ),
        builder: (context, all, _) => ListenableBuilder(
          listenable: _store,
          builder: (context, _) {
            final saved = all.where((p) => _store.contains(p.id));
            final list = switch (_filter) {
              _PicksFilter.onSale => saved.where((p) => p.onSale),
              _PicksFilter.available => saved.where((p) => p.inStock),
              _PicksFilter.all => saved,
            }
                .toList();
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: PsSpace.xs),
                    child: PsFilterChips<_PicksFilter>(
                      selected: _filter,
                      options: const [
                        PsFilterOption(_PicksFilter.all, 'All'),
                        PsFilterOption(_PicksFilter.onSale, 'On Sale'),
                        PsFilterOption(_PicksFilter.available, 'Available'),
                      ],
                      onSelected: (f) => setState(() => _filter = f),
                    ),
                  ),
                ),
                if (list.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: PsEmptyState(icon: Icons.filter_alt_off_outlined, title: 'Nothing matches this filter'),
                  )
                else
                  PsProductGrid(
                    products: list,
                    onTap: (p) => openProduct(context, p.id),
                    footerBuilder: (p) => SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: p.inStock ? () => _moveToCart(p) : null,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: PsColors.textPrimary,
                          side: const BorderSide(color: PsColors.textPrimary),
                          minimumSize: const Size.fromHeight(40),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(p.inStock ? 'MOVE TO CART' : 'SOLD OUT', style: PsText.badge.copyWith(fontSize: 12)),
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: PsSpace.xl)),
              ],
            );
          },
        ),
      ),
    );
  }
}
