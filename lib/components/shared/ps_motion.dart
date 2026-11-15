import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';

import '../../core/theme/ps_tokens.dart';

/// Shared motion pieces so every screen moves the same way (see [PsMotion]).

/// Press feedback: shrinks [child] slightly while a finger is down and eases
/// back on release. Listens to raw pointers, so it never competes with the
/// child's own tap handling or with scrolling — a drag past the touch slop
/// releases the press. Does nothing when [enabled] is false or under reduced
/// motion.
class PsPressable extends StatefulWidget {
  const PsPressable({super.key, required this.child, this.enabled = true, this.scale = 0.96});

  final Widget child;
  final bool enabled;

  /// Pressed size; cards use a gentler 0.98.
  final double scale;

  @override
  State<PsPressable> createState() => _PsPressableState();
}

class _PsPressableState extends State<PsPressable> {
  bool _pressed = false;
  Offset? _down;

  void _set(bool v) {
    if (_pressed != v && mounted) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || PsMotion.reduced(context)) return widget.child;
    return Listener(
      onPointerDown: (e) {
        _down = e.position;
        _set(true);
      },
      onPointerMove: (e) {
        if (_down != null && (e.position - _down!).distance > kTouchSlop) _set(false);
      },
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1,
        duration: PsMotion.press,
        curve: _pressed ? PsMotion.exit : PsMotion.enter,
        child: widget.child,
      ),
    );
  }
}

/// Cross-fades [child] when [value] changes, with a short rise — for totals,
/// counts and labels that update in place. Keeps the same size box while it
/// swaps so nothing around it jumps.
class PsValueSwap extends StatelessWidget {
  const PsValueSwap({super.key, required this.value, required this.child, this.alignment = Alignment.centerRight});

  final Object? value;
  final Widget child;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: PsMotion.duration(context, PsMotion.small),
      switchInCurve: PsMotion.enter,
      switchOutCurve: PsMotion.exit,
      layoutBuilder: (current, previous) => Stack(alignment: alignment, children: [...previous, ?current]),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(animation),
          child: child,
        ),
      ),
      child: KeyedSubtree(key: ValueKey(value), child: child),
    );
  }
}

/// Icon that pops in when it changes (heart filled ↔ outline, nav icons).
class PsIconSwap extends StatelessWidget {
  const PsIconSwap({super.key, required this.icon});

  /// Usually an [Icon]; swaps whenever its icon or color changes.
  final Icon icon;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: PsMotion.duration(context, PsMotion.icon),
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: PsMotion.exit,
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: Tween(begin: 0.6, end: 1.0).animate(animation),
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: KeyedSubtree(key: ValueKey(Object.hash(icon.icon, icon.color)), child: icon),
    );
  }
}

/// Fades [child] in with a small rise the first time it builds. For content
/// that replaces a loading state; not for every item of a scrolling list.
class PsFadeIn extends StatelessWidget {
  const PsFadeIn({super.key, required this.child, this.duration = PsMotion.content, this.offset = 12});

  final Widget child;
  final Duration duration;

  /// Rise in logical pixels.
  final double offset;

  @override
  Widget build(BuildContext context) {
    final d = PsMotion.duration(context, duration);
    if (d == Duration.zero) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: d,
      curve: PsMotion.enter,
      child: child,
      builder: (_, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * offset), child: child),
      ),
    );
  }
}

/// Android page transition: the new page slides in a short way from the
/// right while fading in; the page under it eases left a little. Quicker and
/// calmer than the stock zoom. iOS keeps Cupertino (edge swipe back).
class PsPageTransitionsBuilder extends PageTransitionsBuilder {
  const PsPageTransitionsBuilder();

  @override
  Duration get transitionDuration => PsMotion.page;

  @override
  Duration get reverseTransitionDuration => PsMotion.pageBack;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => psPageTransition(context, animation, secondaryAnimation, child);
}

/// The transition [PsPageTransitionsBuilder] and `fadeRoute` share.
Widget psPageTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child, {
  bool slide = true,
}) {
  if (PsMotion.reduced(context)) return FadeTransition(opacity: animation, child: child);

  final enter = CurvedAnimation(parent: animation, curve: PsMotion.enter, reverseCurve: PsMotion.exit);
  Widget page = FadeTransition(
    opacity: CurvedAnimation(
      parent: animation,
      curve: const Interval(0, 0.7, curve: Curves.easeOut),
    ),
    child: slide
        ? SlideTransition(
            position: Tween(begin: const Offset(0.08, 0), end: Offset.zero).animate(enter),
            child: child,
          )
        : child,
  );
  if (slide) {
    // The page underneath drifts left as the new one covers it.
    page = SlideTransition(
      position: Tween(
        begin: Offset.zero,
        end: const Offset(-0.05, 0),
      ).animate(CurvedAnimation(parent: secondaryAnimation, curve: PsMotion.change)),
      child: page,
    );
  }
  return page;
}
