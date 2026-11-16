import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../core/theme/ps_colors.dart';
import '../../core/theme/ps_tokens.dart';
import '../../core/theme/ps_typography.dart';
import '../../models/catalog.dart';
import '../shared/ps_motion.dart';
import '../shared/states/ps_loading_state.dart';
import 'ps_price.dart';
import 'ps_product_image.dart';
import 'ps_wishlist_button.dart';

/// COM-C01 Product Card — grid tile (default) or list row. Shows only what
/// the product data supports: discount tag only with a real discount, stars
/// only once reviewed, "sold" only once something sold, stock warnings from
/// live stock.
class PsProductCard extends StatelessWidget {
  const PsProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.list = false,
    this.showSeller = true,
    this.footer,
    this.imageAspectRatio = 1,
    this.uniform = false,
  });

  final Product product;
  final VoidCallback onTap;

  /// Horizontal row layout for list view.
  final bool list;
  final bool showSeller;

  /// Extra action under the price (e.g. "Move to cart" on My Picks).
  final Widget? footer;

  /// Width ÷ height of the photo in grid mode. Below 1 is a taller card; the
  /// masonry grid varies it so the feed doesn't look like a spreadsheet.
  final double imageAspectRatio;

  /// Fill the height the parent gives (sideways rows): every card in the row
  /// is the same size and the content arranges itself inside. The name always
  /// keeps room for two lines and the store sits at the bottom.
  final bool uniform;

  @override
  Widget build(BuildContext context) {
    final p = product;
    // Photo in its own rounded, tinted tile inside the card (tint shows while loading).
    final image = Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: ColoredBox(
              color: tileTint(p.id),
              child: PsProductImage(url: p.image, semanticLabel: p.name),
            ),
          ),
        ),
        if (p.onSale) Positioned(top: 10, left: 6, child: PsSaleSticker(percent: p.discountPercent!)),
        Positioned(top: 2, right: 2, child: PsWishlistButton(productId: p.id, size: 17, compact: true)),
        if (!p.inStock)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: PsColors.surface.withAlpha(150),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: PsColors.textPrimary, borderRadius: BorderRadius.circular(8)),
                child: Text(p.unavailableLabel!.toUpperCase(), style: PsText.badge.copyWith(color: PsColors.surface)),
              ),
            ),
          ),
      ],
    );

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: uniform ? MainAxisSize.max : MainAxisSize.min,
      children: [
        SizedBox(
          height: uniform ? 13.5 * 1.3 * 2 + 1 : null,
          child: Text(
            p.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: PsText.ui.copyWith(fontSize: 13.5, height: 1.3, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 6),
        PsPriceDisplay(price: p.price, originalPrice: p.originalPrice, size: PsPriceSize.small),
        _SocialProof(product: p, showReviewCount: list),
        if (p.lowStock) ...[
          const SizedBox(height: 4),
          Text(
            'Only ${p.stock} left',
            style: PsText.caption.copyWith(fontSize: 11.5, color: PsColors.warning, fontWeight: FontWeight.w600),
          ),
        ],
        if (uniform) const Spacer(),
        if (showSeller && p.sellerName.isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.storefront_outlined, size: 13, color: PsColors.textHint),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  p.sellerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PsText.caption.copyWith(fontSize: 11.5),
                ),
              ),
            ],
          ),
        ],
        if (footer != null) ...[const SizedBox(height: PsSpace.sm), footer!],
      ],
    );

    return Semantics(
      button: true,
      label: [
        p.name,
        if (p.onSale) '${p.discountPercent}% off',
        if (p.rating != null) '${p.rating!.toStringAsFixed(1)} stars',
        if (p.soldCount > 0) '${p.soldCount} sold',
        if (p.unavailableLabel != null) p.unavailableLabel!.toLowerCase(),
      ].join(', '),
      child: PsPressable(
        scale: 0.98,
        child: Material(
          color: PsColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: PsColors.border.withAlpha(160)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: list
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 104, height: 104, child: image),
                        Expanded(
                          child: Padding(padding: const EdgeInsets.fromLTRB(PsSpace.sm, 2, 4, 2), child: details),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: uniform ? MainAxisSize.max : MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AspectRatio(aspectRatio: imageAspectRatio, child: image),
                        if (uniform)
                          Expanded(
                            child: Padding(padding: const EdgeInsets.fromLTRB(4, 10, 4, 4), child: details),
                          )
                        else
                          Padding(padding: const EdgeInsets.fromLTRB(4, 10, 4, 4), child: details),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Soft tint behind a product photo; alternates so a grid doesn't look flat.
Color tileTint(int id) => id.isEven ? PsColors.primarySoft : PsColors.neutralSoft;

/// "-30%" Coral sticker, slightly tilted, on a product photo.
class PsSaleSticker extends StatelessWidget {
  const PsSaleSticker({super.key, required this.percent, this.fontSize = 12});

  final int percent;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: PsColors.primary, borderRadius: BorderRadius.circular(8)),
        child: Text(
          '-$percent%',
          style: PsText.badge.copyWith(color: PsColors.onPrimary, fontSize: fontSize),
        ),
      ),
    );
  }
}

/// "★ 4.8 · 1.2k sold": only the parts the product actually has.
class _SocialProof extends StatelessWidget {
  const _SocialProof({required this.product, this.showReviewCount = false});

  final Product product;
  final bool showReviewCount;

  @override
  Widget build(BuildContext context) {
    final p = product;
    if (p.rating == null && p.soldCount <= 0) return const SizedBox.shrink();
    final style = PsText.caption.copyWith(fontSize: 11.5, color: PsColors.textMuted);
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        children: [
          if (p.rating != null) ...[
            Icon(Icons.star_rounded, size: 14, color: PsColors.star),
            const SizedBox(width: 2),
            Text(
              showReviewCount && p.reviewCount > 0
                  ? '${p.rating!.toStringAsFixed(1)} (${p.reviewCount})'
                  : p.rating!.toStringAsFixed(1),
              style: style.copyWith(color: PsColors.textSecondary, fontWeight: FontWeight.w600),
            ),
          ],
          if (p.rating != null && p.soldCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Text('·', style: style),
            ),
          if (p.soldCount > 0)
            Flexible(
              child: Text('${formatSold(p.soldCount)} sold', style: style, overflow: TextOverflow.ellipsis),
            ),
        ],
      ),
    );
  }
}

/// 950 → "950", 1200 → "1.2k", 15000 → "15k".
String formatSold(int n) {
  if (n < 1000) return '$n';
  final k = n / 1000;
  return k >= 10 ? '${k.round()}k' : '${k.toStringAsFixed(1).replaceAll('.0', '')}k';
}

/// Two-column product feed as a sliver. In grid mode the photos alternate
/// between three heights and each column stacks independently (masonry), the
/// way shopping apps keep the eye moving; list mode is one card per row.
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

  /// Photo shapes, repeated down the feed: tall, square, slightly tall.
  static const aspectPattern = [0.8, 1.0, 0.9];

  static double aspectFor(int index) => aspectPattern[index % aspectPattern.length];

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

    return SliverPadding(
      padding: padding,
      sliver: SliverMasonryGrid.count(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childCount: products.length,
        itemBuilder: (_, i) => PsProductCard(
          product: products[i],
          imageAspectRatio: aspectFor(i),
          onTap: () => onTap(products[i]),
          footer: footerBuilder?.call(products[i]),
        ),
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
              LayoutBuilder(
                builder: (context, c) {
                  final w = (MediaQuery.sizeOf(context).width - PsSpace.gutter * 2 - PsSpace.sm) / 2;
                  return SizedBox(
                    width: w,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PsSkeleton(width: w, height: w, radius: PsRadius.lg),
                        const SizedBox(height: 10),
                        const PsSkeleton(height: 12, width: 60),
                        const SizedBox(height: 8),
                        PsSkeleton(height: 14, width: w * 0.8),
                        const SizedBox(height: 8),
                        const PsSkeleton(height: 16, width: 70),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// A sideways row of uniform product cards (Home sections, "You May Also
/// Like"). Horizontal drags scroll the row; vertical ones still scroll the page.
class PsProductCarousel extends StatelessWidget {
  const PsProductCarousel({super.key, required this.products, required this.onTap});

  final List<Product> products;
  final ValueChanged<Product> onTap;

  static const double cardWidth = 156;

  /// Height of the row at the phone's text size (see [PsProductCard.uniform]).
  static double heightOf(BuildContext context) => cardWidth + 150 * MediaQuery.textScalerOf(context).scale(1) + 12;

  @override
  Widget build(BuildContext context) {
    // Every card is the same width and height; the card lays its content out
    // inside (see PsProductCard.uniform). Height fits photo + two-line name +
    // price + stars/sold + low-stock note + store, and grows with the
    // phone's text size setting.
    final rowHeight = heightOf(context);
    return SizedBox(
      height: rowHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(PsSpace.gutter, 2, PsSpace.gutter, 10),
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => SizedBox(
          width: cardWidth,
          height: rowHeight - 12,
          child: PsProductCard(product: products[i], uniform: true, onTap: () => onTap(products[i])),
        ),
      ),
    );
  }
}
