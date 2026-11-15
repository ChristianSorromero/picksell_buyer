import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/ps_colors.dart';
import '../../core/theme/ps_tokens.dart';
import '../../core/theme/ps_typography.dart';
import '../../models/catalog.dart';
import 'ps_product_image.dart';

/// "Flash Picks ................ [See all]": a big tight heading and a pill link.
class PsSectionHeader extends StatelessWidget {
  const PsSectionHeader({super.key, required this.title, this.subtitle, this.onViewAll, this.padding});

  final String title;
  final String? subtitle;
  final VoidCallback? onViewAll;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(PsSpace.gutter, 26, PsSpace.gutter, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(header: true, child: Text(title, style: PsText.hero.copyWith(fontSize: 22))),
                if (subtitle != null) ...[const SizedBox(height: 4), Text(subtitle!, style: PsText.caption)],
              ],
            ),
          ),
          if (onViewAll != null) PsPillLink(label: 'See all', onTap: onViewAll!),
        ],
      ),
    );
  }
}

/// Small rounded "See all" style button (44pt tap area).
class PsPillLink extends StatelessWidget {
  const PsPillLink({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PsRadius.pill),
        child: SizedBox(
          height: PsSize.minTap,
          child: Center(
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: PsColors.surface,
                borderRadius: BorderRadius.circular(PsRadius.pill),
                border: Border.all(color: PsColors.border),
              ),
              child: Text(label, style: PsText.ui),
            ),
          ),
        ),
      ),
    );
  }
}

/// Home hero banners (deals computed from real discounts + admin
/// announcements). Auto-advances every 5s; dots show position.
class PsBannerCarousel extends StatefulWidget {
  const PsBannerCarousel({super.key, required this.banners, required this.onTap});

  final List<HomeBanner> banners;
  final ValueChanged<HomeBanner> onTap;

  @override
  State<PsBannerCarousel> createState() => _PsBannerCarouselState();
}

class _PsBannerCarouselState extends State<PsBannerCarousel> {
  final _controller = PageController();
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    if (widget.banners.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!_controller.hasClients) return;
        final next = (_index + 1) % widget.banners.length;
        _controller.animateToPage(next, duration: PsMotion.slow, curve: PsMotion.curve);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        SizedBox(
          height: 176,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.banners.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: PsSpace.gutter),
              child: _BannerTile(banner: widget.banners[i], onTap: () => widget.onTap(widget.banners[i])),
            ),
          ),
        ),
        if (widget.banners.length > 1) ...[
          const SizedBox(height: PsSpace.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.banners.length; i++)
                AnimatedContainer(
                  duration: PsMotion.normal,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _index ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _index ? PsColors.primary : PsColors.border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _BannerTile extends StatelessWidget {
  const _BannerTile({required this.banner, required this.onTap});

  final HomeBanner banner;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final deals = banner.kind == 'deals';
    return Semantics(
      button: true,
      label: '${banner.title}. ${banner.subtitle ?? ''}',
      excludeSemantics: true,
      child: Material(
        color: deals ? PsColors.primary : PsColors.textPrimary,
        borderRadius: BorderRadius.circular(PsRadius.lg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: Padding(
                  padding: const EdgeInsets.all(PsSpace.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        banner.title.toUpperCase(),
                        maxLines: 2,
                        style: PsText.display.copyWith(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white, height: 1.05),
                      ),
                      if (banner.subtitle != null) ...[
                        const SizedBox(height: 6),
                        Text(banner.subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: PsText.caption.copyWith(color: Colors.white)),
                      ],
                      if (banner.cta != null) ...[
                        const SizedBox(height: PsSpace.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(color: PsColors.textPrimary, borderRadius: BorderRadius.circular(PsRadius.pill)),
                          child: Text(banner.cta!.toUpperCase(), style: PsText.badge.copyWith(color: Colors.white, fontSize: 12)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (banner.image != null)
                Expanded(flex: 4, child: PsProductImage(url: banner.image))
              else
                const Padding(
                  padding: EdgeInsets.all(PsSpace.lg),
                  child: Icon(Icons.campaign_outlined, size: 56, color: Colors.white54),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Home's category shortcuts: a 5-column grid of icons, two rows, all visible
/// at once. Shows up to nine categories and an "All" tile that opens Discover.
class PsCategoryGrid extends StatelessWidget {
  const PsCategoryGrid({super.key, required this.categories, required this.onCategory, required this.onAll});

  final List<String> categories;
  final ValueChanged<String> onCategory;
  final VoidCallback onAll;

  static const _icons = <String, IconData>{
    'beauty': Icons.spa_outlined,
    'books': Icons.menu_book_outlined,
    'clothing': Icons.checkroom_outlined,
    'electronics': Icons.devices_other_outlined,
    'fashion': Icons.diamond_outlined,
    'food & grocery': Icons.local_grocery_store_outlined,
    'home & living': Icons.chair_outlined,
    'pet supplies': Icons.pets_outlined,
    'sports': Icons.sports_basketball_outlined,
    'toys': Icons.toys_outlined,
    'health': Icons.health_and_safety_outlined,
    'gadgets': Icons.headphones_outlined,
    'shoes': Icons.ice_skating_outlined,
    'bags': Icons.shopping_bag_outlined,
  };

  static IconData iconFor(String category) => _icons[category.toLowerCase()] ?? Icons.category_outlined;

  @override
  Widget build(BuildContext context) {
    final shown = categories.take(9).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: PsSpace.gutter - 4),
      child: LayoutBuilder(
        builder: (context, box) {
          final tileWidth = box.maxWidth / 5;
          return Wrap(
            runSpacing: PsSpace.xs,
            children: [
              for (final c in shown)
                SizedBox(width: tileWidth, child: _CategoryTile(label: c, icon: iconFor(c), onTap: () => onCategory(c))),
              SizedBox(
                width: tileWidth,
                child: _CategoryTile(label: 'All', icon: Icons.apps_rounded, onTap: onAll, highlight: true),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.label, required this.icon, required this.onTap, this.highlight = false});

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label == 'All' ? 'All categories' : label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PsRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: highlight ? PsColors.textPrimary : PsColors.primarySoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, size: 24, color: highlight ? PsColors.surface : PsColors.primaryStrong),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: PsText.caption.copyWith(fontSize: 11, height: 1.2, color: PsColors.textSecondary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
