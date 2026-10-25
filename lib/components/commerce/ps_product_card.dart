import 'package:flutter/material.dart';

import '../../core/theme/ps_colors.dart';
import '../../core/theme/ps_tokens.dart';
import '../../core/theme/ps_typography.dart';
import '../../models/catalog.dart';
import '../shared/states/ps_loading_state.dart';
import 'ps_price.dart';
import 'ps_product_image.dart';
import 'ps_rating.dart';
import 'ps_wishlist_button.dart';

/// COM-C01 Product Card — grid tile (default) or list row. Shows only what
/// the product data supports: discount ribbon only with a real discount,
/// rating only once reviewed, stock warnings from live stock.
class PsProductCard extends StatelessWidget {
  const PsProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.list = false,
    this.showSeller = true,
    this.footer,
  });

  final Product product;
  final VoidCallback onTap;

  /// Horizontal row layout for list view.
  final bool list;
  final bool showSeller;

  /// Extra action under the price (e.g. "MOVE TO CART" on My Picks).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final p = product;
    final image = Stack(
      children: [
        Positioned.fill(child: PsProductImage(url: p.image, semanticLabel: p.name)),
        if (p.onSale) Positioned(top: 0, left: 0, child: PsDiscountTag(percent: p.discountPercent!)),
        Positioned(top: 4, right: 4, child: PsWishlistButton(productId: p.id, size: 18)),
        if (!p.inStock)
          Positioned.fill(
            child: Container(
              color: Colors.white.withAlpha(150),
              alignment: Alignment.center,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: PsColors.textPrimary, borderRadius: BorderRadius.circular(4)),
                child: Text('SOLD OUT', style: PsText.badge.copyWith(color: Colors.white)),
              ),
            ),
          ),
      ],
    );

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        PsRatingInline(rating: p.rating, count: list ? p.reviewCount : null),
        if (p.rating != null) const SizedBox(height: 4),
        Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: PsText.bodyStrong.copyWith(fontSize: 14.5, height: 1.3)),
        const SizedBox(height: 6),
        PsPriceDisplay(price: p.price, originalPrice: p.originalPrice, size: PsPriceSize.small),
        if (p.lowStock) ...[
          const SizedBox(height: 4),
          Text('Only ${p.stock} left', style: PsText.caption.copyWith(color: PsColors.warning, fontWeight: FontWeight.w600)),
        ],
        if (showSeller && p.sellerName.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(p.sellerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: PsText.caption.copyWith(fontSize: 11.5)),
        ],
        if (footer != null) ...[const SizedBox(height: PsSpace.sm), footer!],
      ],
    );

    return Semantics(
      button: true,
      label: '${p.name}, ${p.onSale ? '${p.discountPercent}% off, ' : ''}${p.inStock ? '' : 'sold out'}',
      child: Material(
        color: PsColors.surface,
        shape: RoundedRectangleBorder(borderRadius: PsRadius.card, side: const BorderSide(color: PsColors.border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: list
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 112, height: 112, child: image),
                    Expanded(child: Padding(padding: const EdgeInsets.all(PsSpace.sm), child: details)),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AspectRatio(aspectRatio: 1, child: image),
                    Padding(padding: const EdgeInsets.all(PsSpace.sm), child: details),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Two-column grid of [PsProductCard]s as a sliver. Card height follows
/// content, rows align by the tallest card.
class PsProductGrid extends StatelessWidget {
  const PsProductGrid({
    super.key,
    required this.products,
    required this.onTap,
    this.list = false,
    this.padding = const EdgeInsets.symmetric(horizontal: PsSpace.gutter),
    this.footerBuilder,
  });

  final List<Product> products;
  final ValueChanged<Product> onTap;
  final bool list;
  final EdgeInsetsGeometry padding;
  final Widget? Function(Product product)? footerBuilder;

  @override
  Widget build(BuildContext context) {
    if (list) {
      return SliverPadding(
        padding: padding,
        sliver: SliverList.separated(
          itemCount: products.length,
          separatorBuilder: (_, __) => const SizedBox(height: PsSpace.sm),
          itemBuilder: (_, i) => PsProductCard(
            product: products[i],
            list: true,
            onTap: () => onTap(products[i]),
            footer: footerBuilder?.call(products[i]),
          ),
        ),
      );
    }

    final rows = <Widget>[];
    for (var i = 0; i < products.length; i += 2) {
      rows.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var j = i; j < i + 2; j++) ...[
              if (j > i) const SizedBox(width: PsSpace.sm),
              Expanded(
                child: j < products.length
                    ? PsProductCard(product: products[j], onTap: () => onTap(products[j]), footer: footerBuilder?.call(products[j]))
                    : const SizedBox.shrink(),
              ),
            ],
          ],
        ),
      ));
    }

    return SliverPadding(
      padding: padding,
      sliver: SliverList.separated(
        itemCount: rows.length,
        separatorBuilder: (_, __) => const SizedBox(height: PsSpace.sm),
        itemBuilder: (_, i) => rows[i],
      ),
    );
  }
}

/// Skeleton matching [PsProductGrid].
class PsProductGridSkeleton extends StatelessWidget {
  const PsProductGridSkeleton({super.key, this.count = 4});

  final int count;

  @override
  Widget build(BuildContext context) {
    return PsSkeletonGroup(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: PsSpace.gutter),
        child: Wrap(
          spacing: PsSpace.sm,
          runSpacing: PsSpace.sm,
          children: [
            for (var i = 0; i < count; i++)
              LayoutBuilder(builder: (context, c) {
                final w = (MediaQuery.sizeOf(context).width - PsSpace.gutter * 2 - PsSpace.sm) / 2;
                return SizedBox(
                  width: w,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PsSkeleton(width: w, height: w, radius: PsRadius.md),
                      const SizedBox(height: 10),
                      const PsSkeleton(height: 12, width: 60),
                      const SizedBox(height: 8),
                      PsSkeleton(height: 14, width: w * 0.8),
                      const SizedBox(height: 8),
                      const PsSkeleton(height: 16, width: 70),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
