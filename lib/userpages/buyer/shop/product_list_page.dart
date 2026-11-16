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

  /// The selected category ('' = All). Discover keeps it in
  /// [ShellNav.discoverCategory]; a pushed list keeps its own.
  late String _localCategory = widget.initialCategory ?? '';
  String get _category => widget.embedded ? ShellNav.discoverCategory.value : _localCategory;

  /// The search the shown results are for (the field may be mid-typing).
  late String _query = (widget.initialSearch ?? '').trim();
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
    if (widget.embedded) ShellNav.discoverCategory.addListener(_onDiscoverCategory);
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
    if (widget.embedded) ShellNav.discoverCategory.removeListener(_onDiscoverCategory);
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Discover's category changed (its chips, or another screen): show it.
  void _onDiscoverCategory() {
    if (mounted) _reload();
  }

  /// Selects [c] and reloads. On Discover the shared value is the one
  /// written; its listener does the reload.
  void _setCategory(String c) {
    if (widget.embedded && ShellNav.discoverCategory.value != c) {
      ShellNav.discoverCategory.value = c;
      return;
    }
    _localCategory = c;
    _reload();
  }

  /// Header: follows the selected category, then the search, then the
  /// page's own context (Hot Discounts, Discover) — never a stale label.
  String get _title {
    if (_category.isNotEmpty) return _category;
    if (_query.isNotEmpty) return '“$_query”';
    if (widget.embedded) return 'Discover';
    // A list opened for a category or search falls back to every product.
    if (widget.initialCategory != null || widget.initialSearch != null) return 'All Products';
    // Hot Discounts with "On sale" switched off is no longer a deals list.
    if (widget.onSale && !_onSale) return 'All Products';
    return widget.title ?? 'All Products';
  }

  void _clearSearch() {
    _search.clear();
    _reload();
  }

  Future<ProductPage> _fetch(int page) => _catalog.products(
    search: _query,
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

  /// Loads page 1 for the current query. Results of the previous query are
  /// dropped first (unless [keep], for pull-to-refresh), so a new category
  /// never shows the old one's products — loading or after an error.
  Future<void> _reload({bool keep = false}) async {
    final id = ++_requestId;
    setState(() {
      _query = _search.text.trim();
      _loading = true;
      _error = null;
      if (!keep) {
        _products.clear();
        _stores = const [];
        _meta = const PageMeta();
      }
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
        // A failed reload must not leave the previous query's results up.
        _products.clear();
        _stores = const [];
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
          onSelected: _setCategory,
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
      return SliverFillRemaining(
        // The state scrolls itself, so it takes the remaining height as given
        // (measuring it would throw and blank the screen).
        hasScrollBody: true,
        child: _emptyState(),
      );
    }
    return PsProductGrid(products: _products, list: _list, onTap: (p) => openProduct(context, p.id));
  }

  /// Why nothing matched, most specific first: the search, the extra
  /// filters, then the category.
  Widget _emptyState() {
    final filtered = _onSale || !_filters.isEmpty;
    void clearFilters() {
      setState(() {
        _onSale = false;
        _filters = const ProductFilters();
      });
      _reload();
    }

    void showAll() {
      _search.clear();
      setState(() {
        _onSale = false;
        _filters = const ProductFilters();
      });
      _setCategory('');
    }

    if (_query.isNotEmpty) {
      return PsEmptyState(
        icon: Icons.search_off_rounded,
        title: 'No products found',
        message: 'We couldn’t find anything for “$_query”${_category.isEmpty ? '' : ' in $_category'}. '
            'Try another keyword or explore different categories.',
        actionLabel: 'Clear search',
        onAction: _clearSearch,
        secondaryActionLabel: _category.isNotEmpty || filtered ? 'Show all products' : (widget.embedded ? null : 'Browse Discover'),
        onSecondaryAction: _category.isNotEmpty || filtered ? showAll : (widget.embedded ? null : () => ShellNav.openDiscover(context)),
      );
    }
    if (filtered) {
      return PsEmptyState(
        icon: Icons.filter_alt_off_outlined,
        title: 'No products match your filters',
        message: _category.isEmpty ? 'Try a wider price range or remove some filters.' : 'Nothing in $_category matches these filters. Try removing some.',
        actionLabel: 'Clear filters',
        onAction: clearFilters,
      );
    }
    if (_category.isNotEmpty) {
      return PsEmptyState(
        icon: Icons.category_outlined,
        title: 'No products in $_category yet',
        message: 'Sellers haven’t listed anything in this category. Check back soon or browse other categories.',
        actionLabel: 'View all products',
        onAction: showAll,
      );
    }
    return const PsEmptyState(
      icon: Icons.storefront_outlined,
      title: 'Nothing here yet',
      message: 'New products will show up here. Pull down to check again.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return PsAppShell(
      topBar: PsTopBar(
        title: _title,
        showBack: !widget.embedded,
        actions: [CartIconButton(onPressed: () => ShellNav.goTo(context, BuyerTab.cart))],
      ),
      body: PsRefreshable(
        onRefresh: () => _reload(keep: true),
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
