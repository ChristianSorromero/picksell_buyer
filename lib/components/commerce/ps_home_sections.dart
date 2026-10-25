import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/ps_colors.dart';
import '../../core/theme/ps_tokens.dart';
import '../../core/theme/ps_typography.dart';
import '../../models/catalog.dart';
import 'ps_product_image.dart';

/// "Hot Discounts · Curated just for you ............ View All"
class PsSectionHeader extends StatelessWidget {
  const PsSectionHeader({super.key, required this.title, this.subtitle, this.onViewAll});

  final String title;
  final String? subtitle;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(PsSpace.gutter, PsSpace.lg, PsSpace.gutter, PsSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(header: true, child: Text(title, style: PsText.heading.copyWith(fontSize: 20))),
                if (subtitle != null) Text(subtitle!, style: PsText.caption),
              ],
            ),
          ),
          if (onViewAll != null)
            TextButton(
              onPressed: onViewAll,
              style: TextButton.styleFrom(foregroundColor: PsColors.primary, minimumSize: const Size(PsSize.minTap, PsSize.minTap)),
              child: Text('View All', style: PsText.link.copyWith(color: PsColors.primary, fontSize: 15)),
            ),
        ],
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
