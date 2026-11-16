import 'package:flutter/material.dart';

import '../../../components/components.dart';
import '../../../format_utils.dart';
import '../../../models/catalog.dart';
import '../../../models/chat.dart';
import '../../../services/cart_service.dart';
import '../../../services/catalog_service.dart';
import 'review_feedback.dart';
import '../../../services/wishlist_service.dart';
import '../../chats_page.dart';
import '../nav.dart';
import '../shop_header.dart';
import 'product_reviews_page.dart';

/// Product Details: gallery, live price & stock, vouchers, shipping, seller,
/// variations, description, reviews and a sticky Chat / Add to Cart / Buy
/// Now bar (COM-C02…C11).
class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({super.key, required this.productId});

  final int productId;

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  final _catalog = CatalogService();
  List<int> _lastVariationIds = const [];

  Future<ProductDetail> _load() async {
    final d = await _catalog.product(widget.productId);
    WishlistStore.instance.sync([d.product]);
    return d;
  }

  Future<void> _addToCart(ProductDetail d) async {
    await PsProductConfigSheet.show(
      context,
      detail: d,
      actionLabel: 'Add to Cart',
      initialVariationIds: _lastVariationIds,
      onSubmit: (s) async {
        await CartStore.instance.add(d.product, quantity: s.quantity, variationIds: s.variationIds);
        _lastVariationIds = s.variationIds;
        if (!mounted) return;
        PsToast.show(
          context,
          '${d.product.name} added to cart',
          type: PsToastType.success,
          actionLabel: 'View Cart',
          onAction: () => ShellNav.goTo(context, BuyerTab.cart),
        );
      },
    );
  }

  /// Buy Now: the API checks out cart lines only, so the item rides in the cart
  /// for this checkout. Leaving without ordering puts the cart back as it was;
  /// an item already in the cart is bought at the quantity chosen here.
  Future<void> _buyNow(ProductDetail d) async {
    int? lineId;
    var before = 0;
    var options = const <int>[];
    final cart = CartStore.instance;
    final ok = await PsProductConfigSheet.show(
      context,
      detail: d,
      actionLabel: 'Buy now',
      initialVariationIds: _lastVariationIds,
      onSubmit: (s) async {
        final current = await cart.load();
        final same = current.lines.where((l) => l.product.id == d.product.id && _sameOptions(l.variationIds, s.variationIds));
        before = same.isEmpty ? 0 : same.first.quantity;
        options = s.variationIds;
        final id = await cart.add(d.product, quantity: s.quantity, variationIds: s.variationIds);
        if (before > 0) await cart.setLineQuantity(id, s.quantity);
        lineId = id;
        _lastVariationIds = s.variationIds;
      },
    );
    if (!ok || lineId == null || !mounted) return;
    await openCheckout(context, [lineId!]);
    try {
      final after = await cart.load();
      final stillThere = after.lines.any((l) => l.id == lineId);
      if (stillThere) {
        // Not ordered: undo Buy Now.
        if (before > 0) {
          await cart.setLineQuantity(lineId!, before);
        } else {
          await cart.removeLine(lineId!);
        }
      } else if (before > 0) {
        // Ordered: the units that were already in the cart go back.
        await cart.add(d.product, quantity: before, variationIds: options);
      }
    } on ApiException {
      cart.refreshCount();
    }
  }

  static bool _sameOptions(List<int> a, List<int> b) => a.length == b.length && a.toSet().containsAll(b);

  void _chat(ProductDetail d) {
    final s = d.seller;
    if (s == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChatConversationPage(
        contact: ChatContact(id: s.id, name: s.name, initials: s.name.isEmpty ? '?' : s.name[0].toUpperCase(), lastMessage: ''),
        productId: d.product.id,
        productName: d.product.name,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return PsAsyncView<ProductDetail>(
      load: _load,
      refreshable: false,
      errorTitle: 'Couldn’t load this product',
      loading: Scaffold(backgroundColor: PsColors.background, body: PsLoadingState()),
      builder: (context, d, reload) => PsAppShell(
        footer: _BuyBar(
          product: d.product,
          onChat: d.seller == null ? null : () => _chat(d),
          onAdd: () => _addToCart(d),
          onBuy: () => _buyNow(d),
        ),
        body: PsRefreshable(
          onRefresh: reload,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              PsProductGallery(
                images: d.product.images,
                overlay: [
                  Positioned(
                    top: MediaQuery.paddingOf(context).top + PsSpace.xs,
                    left: PsSpace.xs,
                    child: PsIconButton(icon: Icons.arrow_back_ios_new_rounded, size: 18, filled: true, tooltip: 'Back', onPressed: () => Navigator.of(context).maybePop()),
                  ),
                  Positioned(
                    top: MediaQuery.paddingOf(context).top + PsSpace.xs,
                    right: PsSpace.xs,
                    child: Row(children: [
                      Material(type: MaterialType.circle, color: PsColors.surface.withAlpha(235), child: CartIconButton(onPressed: () => ShellNav.goTo(context, BuyerTab.cart))),
                      const SizedBox(width: PsSpace.xs),
                      PsWishlistButton(productId: d.product.id),
                    ]),
                  ),
                ],
              ),
              _Summary(detail: d),
              if (d.vouchers.isNotEmpty || d.shipping != null) _Perks(detail: d),
              if (d.seller != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(PsSpace.gutter, PsSpace.md, PsSpace.gutter, 0),
                  child: PsSellerCard(seller: d.seller!, onVisit: () => openStore(context, d.seller!.id)),
                ),
              if (d.variationGroups.isNotEmpty) _Variations(detail: d, onTap: () => _addToCart(d)),
              _Description(detail: d),
              _Reviews(detail: d),
              _RelatedProducts(key: ValueKey(d.product.id), product: d.product),
              const SizedBox(height: PsSpace.xl),
            ],
          ),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.detail});

  final ProductDetail detail;

  @override
  Widget build(BuildContext context) {
    final p = detail.product;
    final facts = <Widget>[
      if (p.rating != null) PsRatingInline(rating: p.rating, count: p.reviewCount),
      if (p.soldCount > 0) Text('${compactCount(p.soldCount)} sold', style: PsText.caption),
      Text(
        p.inStock ? (p.lowStock ? 'Only ${p.stock} left' : 'In stock') : p.unavailableLabel!,
        style: PsText.caption.copyWith(
          color: p.sellerOnVacation ? PsColors.warning : !p.inStock ? PsColors.error : (p.lowStock ? PsColors.warning : PsColors.success),
          fontWeight: FontWeight.w600,
        ),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(PsSpace.gutter, PsSpace.md, PsSpace.gutter, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(p.name, style: PsText.heading.copyWith(fontSize: 21, height: 1.3)),
          const SizedBox(height: PsSpace.xs),
          PsPriceDisplay(price: p.price, originalPrice: p.originalPrice, discountPercent: p.discountPercent, size: PsPriceSize.large, accent: true, showDiscountTag: true),
          const SizedBox(height: PsSpace.xs),
          Wrap(
            spacing: PsSpace.sm,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (var i = 0; i < facts.length; i++) ...[
                if (i > 0) Text('•', style: PsText.caption),
                facts[i],
              ],
            ],
          ),
          if (p.sellerOnVacation) ...[
            const SizedBox(height: PsSpace.sm),
            PsCard(
              color: PsColors.warningSoft,
              borderColor: PsColors.warning.withAlpha(80),
              child: Row(
                children: [
                  Icon(Icons.beach_access_outlined, size: 18, color: PsColors.warning),
                  const SizedBox(width: PsSpace.xs),
                  Expanded(
                    child: Text('This seller is on vacation and isn’t taking orders right now. You can still save it to My Picks.',
                        style: PsText.caption.copyWith(color: PsColors.warning, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Perks extends StatelessWidget {
  const _Perks({required this.detail});

  final ProductDetail detail;

  @override
  Widget build(BuildContext context) {
    final s = detail.shipping;
    return Padding(
      padding: const EdgeInsets.fromLTRB(PsSpace.gutter, PsSpace.md, PsSpace.gutter, 0),
      child: PsCard(
        padding: const EdgeInsets.symmetric(horizontal: PsSpace.md, vertical: PsSpace.xs),
        child: Column(
          children: [
            if (s != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.local_shipping_outlined),
                title: Text('Shipping: ${formatPesoFixed(s.fee)}', style: PsText.bodyStrong),
                subtitle: Text('${s.name} · Est. ${formatDateRange(s.estimatedFrom, s.estimatedTo)}', style: PsText.caption),
              ),
            if (s != null && detail.vouchers.isNotEmpty) const Divider(),
            if (detail.vouchers.isNotEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.confirmation_number_outlined),
                title: Text('Available Vouchers', style: PsText.bodyStrong),
                subtitle: Text('Apply at checkout', style: PsText.caption),
                trailing: Wrap(
                  spacing: 4,
                  children: [for (final v in detail.vouchers.take(2)) PsTag(v.code)],
                ),
                onTap: () => PsBottomSheet.show<void>(
                  context,
                  title: 'Vouchers',
                  builder: (_) => ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(PsSpace.gutter, 0, PsSpace.gutter, PsSpace.md),
                    children: [
                      for (final v in detail.vouchers) ...[PsVoucherTile(voucher: v), const SizedBox(height: PsSpace.xs)],
                      Text('Choose a voucher in your cart before checking out.', style: PsText.caption, textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Variations extends StatelessWidget {
  const _Variations({required this.detail, required this.onTap});

  final ProductDetail detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(PsSpace.gutter, PsSpace.lg, PsSpace.gutter, 0),
      child: PsVariationSelector(
        groups: detail.variationGroups,
        selected: const {},
        onChanged: (_, __) => onTap(),
      ),
    );
  }
}

class _Description extends StatefulWidget {
  const _Description({required this.detail});

  final ProductDetail detail;

  @override
  State<_Description> createState() => _DescriptionState();
}

class _DescriptionState extends State<_Description> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.detail;
    final text = d.description.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(PsSpace.gutter, PsSpace.md, PsSpace.gutter, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('PRODUCT DETAILS', style: PsText.overline.copyWith(color: PsColors.textPrimary)),
          const SizedBox(height: PsSpace.xs),
          if (d.product.category.isNotEmpty) PsInfoRow(label: 'Category', value: d.product.category),
          if (d.seller?.location.isNotEmpty ?? false) PsInfoRow(label: 'Ships from', value: d.seller!.location),
          PsInfoRow(label: 'Stock', value: '${d.product.stock}'),
          if (text.isNotEmpty) ...[
            const SizedBox(height: PsSpace.xs),
            AnimatedSize(
              duration: PsMotion.normal,
              alignment: Alignment.topCenter,
              child: Text(text, maxLines: _expanded ? null : 4, overflow: _expanded ? null : TextOverflow.fade, style: PsText.body.copyWith(height: 1.6, color: PsColors.textSecondary)),
            ),
            if (text.length > 180)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(onPressed: () => setState(() => _expanded = !_expanded), child: Text(_expanded ? 'Show less' : 'Read more')),
              ),
          ],
        ],
      ),
    );
  }
}

class _Reviews extends StatelessWidget {
  const _Reviews({required this.detail});

  final ProductDetail detail;

  @override
  Widget build(BuildContext context) {
    final s = detail.ratingSummary;
    void openAll() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductReviewsPage(product: detail.product)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PsSectionHeader(title: 'Ratings & Reviews', subtitle: s.count == 0 ? null : '${s.count} reviews', onViewAll: s.count > 0 ? openAll : null),
        Padding(
          padding: PsSpace.page,
          child: s.count == 0
              ? PsCard(child: Text('No reviews yet. Buyers can rate this product after delivery.', style: PsText.bodyMuted))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PsCard(child: PsRatingSummary(summary: s)),
                    for (final r in detail.topReviews) ...[const SizedBox(height: PsSpace.xs), ReviewWithFeedback(key: ValueKey(r.id), review: r)],
                  ],
                ),
        ),
      ],
    );
  }
}

/// "You May Also Like": other products from this product's category (best
/// sellers first, buyable ones ahead), from the same GET /products the
/// listings use. Hidden when the category has nothing else.
class _RelatedProducts extends StatefulWidget {
  const _RelatedProducts({super.key, required this.product});

  final Product product;

  @override
  State<_RelatedProducts> createState() => _RelatedProductsState();
}

class _RelatedProductsState extends State<_RelatedProducts> {
  static const _max = 12;

  late Future<List<Product>> _future = _load();

  Future<List<Product>> _load() async {
    final p = widget.product;
    if (p.category.isEmpty) return const [];
    final page = await CatalogService().products(category: p.category, sort: ProductSort.popular);
    final seen = <int>{p.id};
    final related = [for (final r in page.products) if (seen.add(r.id)) r];
    // Buyable first; the server's best-seller order is kept within each group.
    final ordered = [...related.where((r) => r.inStock), ...related.where((r) => !r.inStock)].take(_max).toList();
    WishlistStore.instance.sync(ordered);
    return ordered;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Product>>(
      future: _future,
      builder: (context, snap) {
        final Widget row;
        if (snap.connectionState != ConnectionState.done) {
          row = SizedBox(
            height: PsProductCarousel.heightOf(context),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(PsSpace.gutter, 2, PsSpace.gutter, 10),
              itemCount: 3,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, __) => const PsSkeleton(width: PsProductCarousel.cardWidth, height: double.infinity, radius: PsRadius.md),
            ),
          );
        } else if (snap.hasError) {
          row = Padding(
            padding: const EdgeInsets.symmetric(horizontal: PsSpace.gutter),
            child: PsCard(
              child: Row(
                children: [
                  Expanded(child: Text('Couldn’t load suggestions.', style: PsText.bodyMuted)),
                  TextButton.icon(
                    onPressed: () => setState(() => _future = _load()),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        } else if (snap.data!.isEmpty) {
          return const SizedBox.shrink(); // nothing else in this category
        } else {
          row = PsProductCarousel(products: snap.data!, onTap: (r) => openProduct(context, r.id));
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PsSectionHeader(
              title: 'You May Also Like',
              subtitle: 'More in ${widget.product.category}',
              onViewAll: snap.hasData && snap.data!.isNotEmpty
                  ? () => openProductList(context, title: widget.product.category, category: widget.product.category)
                  : null,
            ),
            row,
          ],
        );
      },
    );
  }
}

/// Sticky purchase bar.
class _BuyBar extends StatelessWidget {
  const _BuyBar({required this.product, required this.onAdd, required this.onBuy, this.onChat});

  final Product product;
  final VoidCallback onAdd;
  final VoidCallback onBuy;
  final VoidCallback? onChat;

  @override
  Widget build(BuildContext context) {
    final available = product.inStock;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: PsColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: PsColors.border)),
        boxShadow: PsColors.isDark ? null : const [BoxShadow(color: Color(0x141B1B1B), blurRadius: 24, offset: Offset(0, -6))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(PsSpace.gutter, PsSpace.sm, PsSpace.gutter, PsSpace.sm),
          child: Row(
            children: [
              if (onChat != null) ...[
                Material(
                  color: PsColors.primarySoft,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: onChat,
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [const Icon(Icons.chat_bubble_outline_rounded, size: 20), Text('CHAT', style: PsText.badge.copyWith(fontSize: 9.5))],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: PsSpace.xs),
              ],
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    onPressed: available ? onAdd : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: PsColors.textPrimary,
                      side: BorderSide(color: PsColors.textPrimary, width: 1.4),
                      shape: RoundedRectangleBorder(borderRadius: PsRadius.button),
                      textStyle: PsText.ui.copyWith(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                    child: const Text('Add to Cart'),
                  ),
                ),
              ),
              const SizedBox(width: PsSpace.xs),
              Expanded(
                child: PsPrimaryButton(
                    label: available ? 'Buy Now' : (product.sellerOnVacation ? 'Seller Away' : 'Sold Out'),
                    uppercase: false,
                    onPressed: available ? onBuy : null),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
