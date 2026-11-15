import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picksell/components/components.dart';

Widget _app(Widget child, {bool reduceMotion = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  testWidgets('a press shrinks the button and releases on lift', (tester) async {
    await tester.pumpWidget(_app(PsPrimaryButton(label: 'Add to Cart', expand: false, onPressed: () {})));
    double scale() => tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;

    final gesture = await tester.startGesture(tester.getCenter(find.text('Add to Cart')));
    await tester.pump();
    expect(scale(), lessThan(1));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(scale(), 1);
  });

  testWidgets('a drag past the touch slop cancels the press', (tester) async {
    await tester.pumpWidget(_app(PsPrimaryButton(label: 'Buy now', expand: false, onPressed: () {})));
    final gesture = await tester.startGesture(tester.getCenter(find.text('Buy now')));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 40));
    await tester.pump();
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
    await gesture.up();
  });

  testWidgets('reduced motion: no press scaling, value swaps are instant', (tester) async {
    await tester.pumpWidget(
      _app(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PsPrimaryButton(label: 'Checkout', expand: false, onPressed: () {}),
            const PsValueSwap(value: 1, child: Text('₱100')),
          ],
        ),
        reduceMotion: true,
      ),
    );
    expect(find.byType(AnimatedScale), findsNothing);

    await tester.pumpWidget(
      _app(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PsPrimaryButton(label: 'Checkout', expand: false, onPressed: () {}),
            const PsValueSwap(value: 2, child: Text('₱120')),
          ],
        ),
        reduceMotion: true,
      ),
    );
    await tester.pump();
    expect(find.text('₱100'), findsNothing);
    expect(find.text('₱120'), findsOneWidget);
  });

  testWidgets('a loading button ignores repeated taps', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_app(PsPrimaryButton(label: 'Place Order', loading: true, onPressed: () => taps++)));
    await tester.tap(find.byType(ElevatedButton));
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    expect(taps, 0);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
