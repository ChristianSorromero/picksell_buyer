import 'package:flutter/material.dart';

import '../../../components/components.dart';
import '../../../models/catalog.dart';
import '../../../services/catalog_service.dart';
import '../../../services/wishlist_service.dart';
import '../nav.dart';
import '../shop_header.dart';
import 'product_filters_sheet.dart';

/// Product Listing (and the Discover tab): live search, category chips,
/// sort, on-sale filter, grid/list toggle and infinite scroll.
class ProductListPage extends StatefulWidget {
  const ProductListPage({
    super.key,
    this.title,
    this.initialSearch,
    this.initialCategory,
    this.onSale = false,
    this.embedded = false,
  });

  final String? title;
  final String? initialSearch;
  final String? initialCategory;
  final bool onSale;

  /// Shown as a tab (no back button, shop header).
  final bool embedded;

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  final _catalog = CatalogService();
  late final _search = TextEditingController(text: widget.initialSearch ?? '');
  final _scroll = ScrollController();

  List<Category> _categories = [];
  late String _category = widget.initialCategory ?? '';
  late bool _onSale = widget.onSale;
  ProductSort _sort = ProductSort.newest;
  ProductFilters _filters = const ProductFilters();
  bool _list = false;

  /// From the latest first page: stores matching the search, and the
  /// provinces the location filter offers.
  List<SellerSummary> _stores = const [];
  List<String> _provinces = const [];

  final List<Product> _products = [];
  PageMeta _meta = const PageMeta();
  bool _loading = true;
  bool _loadingMore = false;
  Object? _error;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 600) _loadMore();
    });
    _catalog
        .categories()
        .then((c) {
          if (mounted) setState(() => _categories = c);
        })
        .catchError((_) {});
    _reload();
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<ProductPage> _fetch(int page) => _catalog.products(
    search: _search.text.trim(),
    category: _category,
    sort: _sort,
    onSale: _onSale,
    minPrice: _filters.minPrice,
    maxPrice: _filters.maxPrice,
    minRating: _filters.minRating,
    location: _filters.location,
    page: page,
  );

  Future<void> _openFilters() async {
    final picked = await showProductFilters(context, current: _filters, provinces: _provinces);
    if (picked == null || !mounted) return;
    setState(() => _filters = picked);
    _reload();
  }

  Future<void> _reload() async {
    final id = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _fetch(1);
      if (!mounted || id != _requestId) return; // a newer query won
      WishlistStore.instance.sync(page.products);
      setState(() {
        _products
          ..clear()
          ..addAll(page.products);
        _meta = page.meta;
        _stores = page.stores;
        if (page.provinces.isNotEmpty) _provinces = page.provinces;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_meta.hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await _fetch(_meta.currentPage + 1);
      if (!mounted) return;
      WishlistStore.instance.sync(page.products);
      setState(() {
        _products.addAll(page.products);
        _meta = page.meta;
      });
    } catch (e) {
      if (mounted) PsToast.error(context, errorMessage(e));
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Widget _controls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(PsSpace.gutter, PsSpace.xs, PsSpace.gutter, 0),
          child: PsSearchBar(
            controller: _search,
            hint: widget.embedded ? 'Filter all products…' : 'Search products…',
            onChanged: (_) => _reload(),
            onSubmitted: (_) => _reload(),
          ),
        ),
        const SizedBox(height: PsSpace.xs),
        PsFilterChips<String>(
          selected: _category,
          options: [const PsFilterOption('', 'All'), for (final c in _categories) PsFilterOption(c.name, c.name)],
          onSelected: (c) {
            setState(() => _category = c);
            _reload();
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: PsSpace.xs),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: PsSpace.xs),
                child: PsToggleChip(
                  label: 'On sale',
                  selected: _onSale,
                  onChanged: (v) {
                    setState(() => _onSale = v);
                    _reload();
                  },
                ),
              ),
              const Spacer(),
              PsIconButton(
                icon: Icons.tune_rounded,
                tooltip: _filters.isEmpty ? 'Filters' : 'Filters, ${_filters.count} on',
                badgeCount: _filters.count,
                onPressed: _openFilters,
              ),
              PsSortButton<ProductSort>(
                selected: _sort,
                options: [for (final s in ProductSort.values) PsFilterOption(s, s.label)],
                onSelected: (s) {
                  setState(() => _sort = s);
                  _reload();
                },
              ),
              PsIconButton(
                icon: _list ? Icons.grid_view_rounded : Icons.view_agenda_outlined,
                tooltip: _list ? 'Grid view' : 'List view',
                onPressed: () => setState(() => _list = !_list),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Stores matching the search, above the products (website: browse page).
  Widget _storeRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: PsSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(PsSpace.gutter, PsSpace.xs, PsSpace.gutter, PsSpace.xs),
            child: Text('Stores', style: PsText.bodyStrong),
          ),
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: PsSpace.gutter),
              itemCount: _stores.length,
              separatorBuilder: (_, __) => const SizedBox(width: PsSpace.xs),
              itemBuilder: (_, i) {
                final s = _stores[i];
                return PsPressable(
                  scale: 0.98,
                  child: Material(
                    color: PsColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: PsRadius.card,
                      side: BorderSide(color: PsColors.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => openStore(context, s.id),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: PsSpace.sm),
                        child: Row(
                          children: [
                            PsSellerAvatar(name: s.name, logo: s.logo, size: 36),
                            const SizedBox(width: PsSpace.xs),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 160),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s.name, style: PsText.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  Text(
                                    [
                                      if (s.location.isNotEmpty) s.location,
                                      if (s.productCount > 0) '${s.productCount} products',
                                    ].join(' · '),
                                    style: PsText.caption,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _results() {
    if (_loading && _products.isEmpty) {
      return const SliverToBoxAdapter(child: PsProductGridSkeleton(count: 6));
    }
    final e = _error;
    if (e != null && _products.isEmpty) {
      return SliverFillRemaining(
        // The state scrolls itself, so it takes the remaining height as given
        // (measuring it would throw and blank the screen).
        hasScrollBody: true,
        child: e is ApiException && e.isNetworkError
            ? PsOfflineState(onRetry: _reload)
            : PsErrorState(message: errorMessage(e), onRetry: _reload),
      );
    }
    if (_products.isEmpty) {
      final filtered = _search.text.isNotEmpty || _category.isNotEmpty || _onSale || !_filters.isEmpty;
      return SliverFillRemaining(
        // The state scrolls itself, so it takes the remaining height as given
        // (measuring it would throw and blank the screen).
        hasScrollBody: true,
        child: PsEmptyState(
          icon: Icons.search_off_rounded,
          title: filtered ? 'No matches found' : 'Nothing here yet',
          message: filtered ? 'Try a different keyword or remove some filters.' : 'New products will show up here.',
          actionLabel: filtered ? 'Clear filters' : null,
          onAction: filtered
              ? () {
                  _search.clear();
                  setState(() {
                    _category = '';
                    _onSale = false;
                    _filters = const ProductFilters();
                  });
                  _reload();
                }
              : null,
        ),
      );
    }
    return PsProductGrid(products: _products, list: _list, onTap: (p) => openProduct(context, p.id));
  }

  @override
  Widget build(BuildContext context) {
    return PsAppShell(
      topBar: PsTopBar(
        title: widget.title ?? 'Products',
        showBack: !widget.embedded,
        actions: [CartIconButton(onPressed: () => ShellNav.goTo(context, BuyerTab.cart))],
      ),
      body: PsRefreshable(
        onRefresh: _reload,
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _controls()),
            if (_stores.isNotEmpty) SliverToBoxAdapter(child: _storeRow()),
            if (!_loading && _products.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(PsSpace.gutter, 0, PsSpace.gutter, PsSpace.xs),
                  child: Text('${_meta.total} ${_meta.total == 1 ? 'product' : 'products'}', style: PsText.caption),
                ),
              ),
            _results(),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: PsSpace.lg),
                child: _loadingMore ? const PsLoadingState() : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
