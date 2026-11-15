import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app_assets.dart';
import '../components/components.dart';
import '../page_transitions.dart';
import '../services/onboarding_store.dart';
import 'welcome_page.dart';

/// First-launch intro: three slides the buyer can swipe through (or step with
/// the round button), then the welcome page. Illustrations drift with the
/// swipe (parallax) and float gently; feature chips bob around them. Shown
/// once per install.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _Slide {
  const _Slide({required this.title, required this.body, required this.chips, this.asset});

  final String title;
  final String body;
  final String? asset;
  final List<(IconData, String)> chips;
}

const _slides = [
  _Slide(
    title: 'SHOP SMART.\nBUY FAST.',
    body: 'Find the best products, deals and sellers, all in one place.',
    asset: AppAssets.landing1,
    chips: [(Icons.local_offer_outlined, 'Daily deals'), (Icons.verified_outlined, 'Verified sellers')],
  ),
  _Slide(
    title: 'DISCOVER\nUNIQUE FINDS.',
    body: 'Explore products from sellers around the Philippines and save your favourites to My Picks.',
    asset: AppAssets.landing2,
    chips: [(Icons.storefront_outlined, 'Local stores'), (Icons.favorite_border_rounded, 'My Picks')],
  ),
  _Slide(
    title: 'TRACK EVERY\nORDER.',
    body: 'Pay cash on delivery and follow your parcel with Pickrush, from the seller to your door.',
    chips: [(Icons.payments_outlined, 'Cash on delivery'), (Icons.local_shipping_outlined, 'Live tracking')],
  ),
];

class _OnboardingPageState extends State<OnboardingPage> with SingleTickerProviderStateMixin {
  final _pages = PageController();
  late final AnimationController _float = AnimationController(vsync: this, duration: const Duration(seconds: 4))
    ..repeat();
  double _page = 0;

  @override
  void initState() {
    super.initState();
    _pages.addListener(() => setState(() => _page = _pages.page ?? 0));
  }

  @override
  void dispose() {
    _pages.dispose();
    _float.dispose();
    super.dispose();
  }

  bool get _last => _page.round() == _slides.length - 1;

  Future<void> _finish() async {
    await OnboardingStore.markSeen();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(fadeRoute(const WelcomePage()), (_) => false);
  }

  void _next() {
    if (_last) {
      _finish();
    } else {
      _pages.nextPage(duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      backgroundColor: PsColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar: brand mark and Skip (hidden on the last slide).
            Padding(
              padding: const EdgeInsets.fromLTRB(PsSpace.gutter + 4, PsSpace.xs, PsSpace.xs, 0),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(AppAssets.brandMark, width: 34, height: 34, errorBuilder: (_, __, ___) => const SizedBox(width: 34)),
                  ),
                  const Spacer(),
                  AnimatedOpacity(
                    opacity: _last ? 0 : 1,
                    duration: PsMotion.normal,
                    child: TextButton(
                      onPressed: _last ? null : _finish,
                      style: TextButton.styleFrom(foregroundColor: PsColors.textSecondary, minimumSize: const Size(56, 44)),
                      child: Text('Skip', style: PsText.bodyStrong.copyWith(color: PsColors.textSecondary)),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: _slides.length,
                itemBuilder: (context, i) {
                  final delta = (_page - i).clamp(-1.0, 1.0);
                  return _SlideView(
                    slide: _slides[i],
                    index: i,
                    delta: delta,
                    float: reduceMotion ? null : _float,
                  );
                },
              ),
            ),
            // Dots and the round "next" button with a progress ring.
            Padding(
              padding: const EdgeInsets.fromLTRB(PsSpace.gutter + 8, PsSpace.sm, PsSpace.gutter + 8, PsSpace.lg),
              child: Row(
                children: [
                  _Dots(page: _page, count: _slides.length),
                  const Spacer(),
                  _NextButton(
                    progress: (_page + 1) / _slides.length,
                    expanded: _last,
                    onTap: _next,
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

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide, required this.index, required this.delta, required this.float});

  final _Slide slide;
  final int index;

  /// -1..1: how far this slide is from the centre (for parallax and fades).
  final double delta;
  final Animation<double>? float;

  @override
  Widget build(BuildContext context) {
    final fade = 1 - delta.abs();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Transform.translate(
            // The illustration moves slower than the page: a soft parallax.
            offset: Offset(delta * 120, 0),
            child: _Illustration(slide: slide, index: index, float: float),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(PsSpace.gutter + 8, PsSpace.md, PsSpace.gutter + 8, 0),
          child: Opacity(
            opacity: fade.clamp(0, 1),
            child: Transform.translate(
              offset: Offset(delta * 40, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    slide.title,
                    style: GoogleFonts.montserrat(fontSize: 30, fontWeight: FontWeight.w800, height: 1.08, letterSpacing: -0.5, color: PsColors.textPrimary),
                  ),
                  const SizedBox(height: PsSpace.sm),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: Text(slide.body, style: GoogleFonts.openSans(fontSize: 14.5, height: 1.5, color: PsColors.textMuted)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Illustration extends StatelessWidget {
  const _Illustration({required this.slide, required this.index, required this.float});

  final _Slide slide;
  final int index;
  final Animation<double>? float;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final size = math.min(box.maxWidth - 32, box.maxHeight - 16);
        final art = slide.asset != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Image.asset(slide.asset!, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              )
            : const _TrackingArt();

        Widget bob(Widget child, double phase, double amp) {
          final f = float;
          if (f == null) return child;
          return AnimatedBuilder(
            animation: f,
            child: child,
            builder: (_, c) => Transform.translate(offset: Offset(0, math.sin((f.value + phase) * 2 * math.pi) * amp), child: c),
          );
        }

        return Center(
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Soft coral halo.
                Container(
                  width: size * 0.92,
                  height: size * 0.92,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [PsColors.primarySoft, Color(0x00FAEBE8)], stops: [0.55, 1]),
                  ),
                ),
                Padding(padding: EdgeInsets.all(size * 0.06), child: bob(art, 0, 6)),
                Positioned(left: 0, top: size * 0.12, child: bob(_Chip(icon: slide.chips[0].$1, label: slide.chips[0].$2), 0.25, 8)),
                Positioned(right: 0, bottom: size * 0.14, child: bob(_Chip(icon: slide.chips[1].$1, label: slide.chips[1].$2), 0.6, 8)),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Slide 3's drawn illustration: a parcel's journey as a tracking card.
class _TrackingArt extends StatelessWidget {
  const _TrackingArt();

  @override
  Widget build(BuildContext context) {
    Widget step(IconData icon, String label, String sub, {bool done = false, bool current = false, bool last = false}) {
      final color = done || current ? PsColors.primary : PsColors.border;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: current ? PsColors.primary : (done ? PsColors.primarySoft : PsColors.surfaceMuted),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: current ? PsColors.onPrimary : (done ? PsColors.primaryStrong : PsColors.textHint)),
              ),
              if (!last) Container(width: 2, height: 22, color: color),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: PsText.bodyStrong.copyWith(fontSize: 13)),
                  Text(sub, style: PsText.caption.copyWith(fontSize: 11)),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 260),
        padding: const EdgeInsets.all(PsSpace.md),
        decoration: BoxDecoration(
          color: PsColors.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 30, offset: Offset(0, 12))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.inventory_2_outlined, size: 18, color: PsColors.textSecondary),
                const SizedBox(width: 6),
                Text('Your parcel', style: PsText.caption.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: PsSpace.sm),
            step(Icons.check_rounded, 'Order placed', 'Seller is preparing it', done: true),
            step(Icons.local_shipping_outlined, 'With Pickrush', 'On the way to your city', current: true),
            step(Icons.home_outlined, 'Delivered', 'Pay the rider in cash', last: true),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: PsColors.surface,
        borderRadius: BorderRadius.circular(PsRadius.pill),
        boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: PsColors.primaryStrong),
          const SizedBox(width: 6),
          Text(label, style: PsText.caption.copyWith(fontWeight: FontWeight.w700, color: PsColors.textPrimary)),
        ],
      ),
    );
  }
}

/// Dots that stretch smoothly with the swipe, not just on page change.
class _Dots extends StatelessWidget {
  const _Dots({required this.page, required this.count});

  final double page;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Slide ${page.round() + 1} of $count',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++)
            Builder(builder: (_) {
              final t = (1 - (page - i).abs()).clamp(0.0, 1.0);
              return Container(
                margin: const EdgeInsets.only(right: 6),
                width: 8 + 20 * t,
                height: 8,
                decoration: BoxDecoration(
                  color: Color.lerp(PsColors.border, PsColors.primary, t),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
        ],
      ),
    );
  }
}

/// Round arrow button wrapped in a ring that fills a third per slide; on the
/// last slide it widens into "Get started".
class _NextButton extends StatelessWidget {
  const _NextButton({required this.progress, required this.expanded, required this.onTap});

  final double progress;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: expanded ? 'Get started' : 'Next slide',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          width: expanded ? 172 : 68,
          height: 68,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (!expanded)
                SizedBox.square(
                  dimension: 68,
                  child: CircularProgressIndicator(
                    value: progress.clamp(0, 1),
                    strokeWidth: 3,
                    backgroundColor: PsColors.border,
                    color: PsColors.primary,
                  ),
                ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                width: expanded ? 172 : 54,
                height: expanded ? 60 : 54,
                decoration: BoxDecoration(
                  color: PsColors.primary,
                  borderRadius: BorderRadius.circular(PsRadius.pill),
                  boxShadow: const [BoxShadow(color: Color(0x40FF6F61), blurRadius: 16, offset: Offset(0, 6))],
                ),
                alignment: Alignment.center,
                child: expanded
                    ? FittedBox(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Get started', style: PsText.button),
                            const SizedBox(width: 6),
                            Icon(Icons.arrow_forward_rounded, size: 20, color: PsColors.onPrimary),
                          ],
                        ),
                      )
                    : Icon(Icons.arrow_forward_rounded, color: PsColors.onPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
