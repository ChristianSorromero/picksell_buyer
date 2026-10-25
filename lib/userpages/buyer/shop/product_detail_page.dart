import 'package:flutter/material.dart';

import '../../../components/components.dart';
import '../../../format_utils.dart';
import '../../../models/catalog.dart';
import '../../../models/chat.dart';
import '../../../services/cart_service.dart';
import '../../../services/catalog_service.dart';
import '../../../services/recently_viewed_service.dart';
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
    RecentlyViewed.add(d.product.id);
    return d;
  }

  Future<void> _addToCart(ProductDetail d) async {
    await PsProductConfigSheet.show(
      context,
      detail: d,
      actionLabel: 'Add to cart',
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

  Future<void> _buyNow(ProductDetail d) async {
    int? lineId;
    final ok = await PsProductConfigSheet.show(
      context,
      detail: d,
      actionLabel: 'Buy now',
      initialVariationIds: _lastVariationIds,
      onSubmit: (s) async {
        lineId = await CartStore.instance.add(d.product, quantity: s.quantity, variationIds: s.variationIds);
      },
    );
    if (ok && lineId != null && mounted) openCheckout(context, [lineId!]);
  }

  void _chat(ProductDetail d) {
    final s = d.seller;
    if (s == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChatConversationPage(
        contact: ChatContact(id: s.id, name: s.name, initials: s.name.isEmpty ? '?' : s.name[0].toUpperCase(), lastMessage: ''),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return PsAsyncView<ProductDetail>(
      load: _load,
      refreshable: false,
      errorTitle: 'Couldn’t load this product',
      loading: const Scaffold(backgroundColor: PsColors.background, body: PsLoadingState()),
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
                      Material(type: MaterialType.circle, color: Colors.white.withAlpha(235), child: CartIconButton(onPressed: () => ShellNav.goTo(context, BuyerTab.cart))),
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
        p.inStock ? (p.lowStock ? 'Only ${p.stock} left' : 'In stock') : 'Sold out',
        style: PsText.caption.copyWith(
          color: !p.inStock ? PsColors.error : (p.lowStock ? PsColors.warning : PsColors.success),
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
                    for (final r in detail.topReviews) ...[const SizedBox(height: PsSpace.xs), PsReviewCard(review: r)],
                  ],
                ),
        ),
      ],
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
      decoration: const BoxDecoration(color: PsColors.surface, border: Border(top: BorderSide(color: PsColors.border))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(PsSpace.gutter, PsSpace.sm, PsSpace.gutter, PsSpace.sm),
          child: Row(
            children: [
              if (onChat != null) ...[
                Material(
                  color: PsColors.surfaceMuted,
                  borderRadius: PsRadius.button,
                  child: InkWell(
                    borderRadius: PsRadius.button,
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
                      side: const BorderSide(color: PsColors.textPrimary, width: 1.4),
                      shape: RoundedRectangleBorder(borderRadius: PsRadius.button),
                      textStyle: PsText.bodyStrong.copyWith(fontSize: 15),
                    ),
                    child: const Text('Add to Cart'),
                  ),
                ),
              ),
              const SizedBox(width: PsSpace.xs),
              Expanded(
                child: PsPrimaryButton(label: available ? 'Buy Now' : 'Sold Out', uppercase: false, onPressed: available ? onBuy : null),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
