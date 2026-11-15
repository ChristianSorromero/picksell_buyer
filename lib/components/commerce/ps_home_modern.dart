import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/status/order_status.dart';
import '../../core/theme/ps_colors.dart';
import '../../core/theme/ps_tokens.dart';
import '../../core/theme/ps_typography.dart';
import '../../models/catalog.dart';
import '../../models/order.dart';
import 'ps_product_image.dart';

/// Colors for the dark blocks (order card, small hero tile): Eerie Black in
/// light mode, a raised grey in dark mode, always with Bone White text.
Color get _darkBlock => PsColors.isDark ? const Color(0xFF2A2A2A) : const Color(0xFF1B1B1B);
Color get _darkRaised => PsColors.isDark ? const Color(0xFF363636) : const Color(0xFF2F2F2F);
const _onDark = Color(0xFFF9F8F6);
const _onDarkMuted = Color(0xFFA3A3AB);
const _trackOff = Color(0xFF3A3A3A);

/// "Arriving today": the buyer's order that is on its way, with a segmented
/// Pick Thread (placed → preparing → in transit → out for delivery → delivered).
class PsActiveOrderCard extends StatelessWidget {
  const PsActiveOrderCard({super.key, required this.order, required this.onTap});

  final OrderSummaryItem order;
  final VoidCallback onTap;

  static const _milestones = [
    ('Placed', OrderStatus.placed),
    ('Preparing', OrderStatus.preparing),
    ('In transit', OrderStatus.pickedUp),
    ('Out for delivery', OrderStatus.outForDelivery),
    ('Delivered', OrderStatus.delivered),
  ];

  /// Index of the last milestone reached.
  int get _reached {
    final at = OrderStatus.happyPath.indexOf(order.status);
    var r = 0;
    for (var i = 0; i < _milestones.length; i++) {
      if (at >= OrderStatus.happyPath.indexOf(_milestones[i].$2)) r = i;
    }
    return r;
  }

  String get _headline => switch (order.status) {
        OrderStatus.outForDelivery => 'Arriving today',
        OrderStatus.assignedToRider || OrderStatus.sorted || OrderStatus.atSortingCenter || OrderStatus.pickedUp => 'On its way',
        OrderStatus.delivered => 'Delivered',
        _ => 'Seller is preparing it',
      };

  @override
  Widget build(BuildContext context) {
    final reached = _reached;
    return Semantics(
      button: true,
      label: '$_headline. ${order.orderNumber}, ${order.productName}. ${order.status.buyerLabel}. Track order',
      excludeSemantics: true,
      child: Material(
        color: _darkBlock,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(PsSpace.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(color: _darkRaised, borderRadius: BorderRadius.circular(16)),
                      clipBehavior: Clip.antiAlias,
                      child: PsProductImage(url: order.image, iconSize: 22),
                    ),
                    const SizedBox(width: PsSpace.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_headline, style: PsText.ui.copyWith(fontSize: 17, fontWeight: FontWeight.w800, color: _onDark)),
                          const SizedBox(height: 2),
                          Text(
                            '${order.orderNumber} · ${order.productName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: PsText.caption.copyWith(fontSize: 12, color: _onDarkMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: PsSpace.xs),
                    Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: PsColors.primary, borderRadius: BorderRadius.circular(18)),
                      child: Text('Track', style: PsText.ui.copyWith(fontWeight: FontWeight.w800, color: PsColors.onPrimary)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    for (var i = 0; i < _milestones.length; i++) ...[
                      if (i > 0) const SizedBox(width: 4),
                      Expanded(
                        child: Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: i <= reached ? PsColors.primary : _trackOff,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_milestones.first.$1, style: _label(false)),
                    Text(_milestones[reached].$1, style: _label(true)),
                    Text(_milestones.last.$1, style: _label(false)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  TextStyle _label(bool on) => PsText.ui.copyWith(fontSize: 11, fontWeight: on ? FontWeight.w800 : FontWeight.w600, color: on ? _onDark : _onDarkMuted);
}

/// Bento hero: the live banners rotate in a tall Coral tile on the left; two
/// small tiles on the right ("Hot Discounts" with the real top discount, and a
/// shortcut tile).
class PsBentoHero extends StatelessWidget {
  const PsBentoHero({
    super.key,
    required this.banners,
    required this.onBanner,
    required this.topDiscount,
    required this.onDeals,
    required this.onPicks,
  });

  final List<HomeBanner> banners;
  final ValueChanged<HomeBanner> onBanner;

  /// Biggest live discount, or null when nothing is on sale.
  final int? topDiscount;
  final VoidCallback onDeals;
  final VoidCallback onPicks;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: PsSpace.gutter),
      child: SizedBox(
        height: 236,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 3, child: _BannerRotator(banners: banners, onTap: onBanner)),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _SmallTile(
                      color: _darkBlock,
                      label: 'Hot Discounts',
                      big: topDiscount == null ? 'Deals' : 'Up to\n$topDiscount%',
                      bigColor: PsColors.primary,
                      caption: 'Biggest markdowns',
                      captionColor: _onDark,
                      labelColor: _onDarkMuted,
                      onTap: onDeals,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: _SmallTile(
                      color: PsColors.primarySoft,
                      label: 'Saved',
                      big: 'My Picks',
                      bigColor: PsColors.textPrimary,
                      caption: 'Your saved items',
                      captionColor: PsColors.textSecondary,
                      labelColor: PsColors.textSecondary,
                      icon: Icons.favorite_rounded,
                      onTap: onPicks,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallTile extends StatelessWidget {
  const _SmallTile({
    required this.color,
    required this.label,
    required this.big,
    required this.bigColor,
    required this.caption,
    required this.captionColor,
    required this.labelColor,
    required this.onTap,
    this.icon,
  });

  final Color color;
  final String label;
  final String big;
  final Color bigColor;
  final String caption;
  final Color captionColor;
  final Color labelColor;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${big.replaceAll('\n', ' ')}. $caption',
      excludeSemantics: true,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(PsRadius.xl),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              if (icon != null)
                Positioned(right: -10, bottom: -12, child: Transform.rotate(angle: 0.2, child: Icon(icon, size: 64, color: PsColors.primary))),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(label, style: PsText.ui.copyWith(fontSize: 12, color: labelColor)),
                    Text(big, maxLines: 2, style: PsText.hero.copyWith(fontSize: 21, color: bigColor)),
                    Text(caption, maxLines: 1, overflow: TextOverflow.ellipsis, style: PsText.caption.copyWith(fontSize: 11, color: captionColor)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The tall Coral tile: one banner at a time, auto-advancing every 5 s.
class _BannerRotator extends StatefulWidget {
  const _BannerRotator({required this.banners, required this.onTap});

  final List<HomeBanner> banners;
  final ValueChanged<HomeBanner> onTap;

  @override
  State<_BannerRotator> createState() => _BannerRotatorState();
}

class _BannerRotatorState extends State<_BannerRotator> {
  final _controller = PageController();
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    if (widget.banners.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!_controller.hasClients) return;
        _controller.animateToPage((_index + 1) % widget.banners.length, duration: PsMotion.slow, curve: PsMotion.curve);
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
    final banners = widget.banners.isEmpty
        ? const [HomeBanner(kind: 'deals', title: 'Fresh picks', subtitle: 'New from PickSell sellers', cta: 'Shop now')]
        : widget.banners;
    return Material(
      color: PsColors.primary,
      borderRadius: BorderRadius.circular(PsRadius.xl),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: banners.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => _BannerFace(banner: banners[i], onTap: () => widget.onTap(banners[i])),
          ),
          if (banners.length > 1)
            Positioned(
              right: 14,
              top: 16,
              child: Row(
                children: [
                  for (var i = 0; i < banners.length; i++)
                    AnimatedContainer(
                      duration: PsMotion.normal,
                      margin: const EdgeInsets.only(left: 4),
                      width: i == _index ? 14 : 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: PsColors.onPrimary.withAlpha(i == _index ? 255 : 90),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _BannerFace extends StatelessWidget {
  const _BannerFace({required this.banner, required this.onTap});

  final HomeBanner banner;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const ink = PsColors.onPrimary; // Eerie Black on Coral, never white.
    return Semantics(
      button: true,
      label: '${banner.title}. ${banner.subtitle ?? ''}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            if (banner.image != null)
              Positioned(
                right: -22,
                bottom: -18,
                width: 132,
                height: 132,
                child: Transform.rotate(
                  angle: -0.14,
                  child: ClipRRect(borderRadius: BorderRadius.circular(28), child: PsProductImage(url: banner.image)),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(color: const Color(0xFF1B1B1B), borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      banner.kind == 'deals' ? 'DEALS' : 'PICKSELL',
                      style: PsText.badge.copyWith(color: const Color(0xFFF9F8F6), fontSize: 10.5, letterSpacing: 1),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    banner.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: PsText.hero.copyWith(fontSize: 28, color: ink, height: 1.0),
                  ),
                  if (banner.subtitle != null) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 130,
                      child: Text(
                        banner.subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: PsText.ui.copyWith(fontSize: 12.5, color: ink, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(color: Color(0xFF1B1B1B), shape: BoxShape.circle),
                    child: const Icon(Icons.arrow_forward_rounded, size: 20, color: Color(0xFFF9F8F6)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Four shortcut tiles under the hero.
class PsQuickActions extends StatelessWidget {
  const PsQuickActions({super.key, required this.actions});

  /// (label, icon, highlight, onTap)
  final List<(String, IconData, bool, VoidCallback)> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: PsSpace.gutter),
      child: Row(
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: _QuickTile(action: actions[i])),
          ],
        ],
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({required this.action});

  final (String, IconData, bool, VoidCallback) action;

  @override
  Widget build(BuildContext context) {
    final (label, icon, highlight, onTap) = action;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: PsColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PsRadius.lg), side: BorderSide(color: PsColors.border)),
        child: InkWell(
          onTap: onTap,
          customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PsRadius.lg)),
          child: SizedBox(
            height: 84,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: highlight ? PsColors.primary : PsColors.primarySoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: highlight ? PsColors.onPrimary : PsColors.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: PsText.ui.copyWith(fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A tinted band with rounded top corners for a featured strip (Flash/Hot deals).
class PsTintedPanel extends StatelessWidget {
  const PsTintedPanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 28),
      padding: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: PsColors.isDark ? const Color(0xFF1C1C1C) : const Color(0xFFF1EEE8),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: child,
    );
  }
}
