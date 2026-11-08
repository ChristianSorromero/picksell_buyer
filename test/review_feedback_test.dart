import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picksell/core/theme/ps_theme.dart';
import 'package:picksell/models/catalog.dart';
import 'package:picksell/services/catalog_service.dart';
import 'package:picksell/services/review_service.dart';
import 'package:picksell/userpages/buyer/shop/product_reviews_page.dart';

import 'support/fake_api.dart';

Widget _app(Widget home) => MaterialApp(theme: PsTheme.light, home: home);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

const _tee = Product(id: 7, name: 'Cotton Basic Tee', price: 400);

void main() {
  final api = FakeBuyerApi();

  setUp(() async {
    api.reset();
    await api.install();
  });

  test('reviews carry the buyer’s own vote and the report reasons', () async {
    final page = await CatalogService().reviews(7);
    final others = page.reviews.first;
    expect((others.helpfulCount, others.isHelpful, others.isMine, others.sellerReply), (2, false, false, 'Salamat po!'));
    expect(page.reviews.last.isMine, isTrue);
    expect(page.reportReasons.map((r) => r.code), ['fake', 'spam']);

    final service = ReviewService();
    expect(await service.setHelpful(31, helpful: true), (helpful: true, count: 3));
    expect(await service.setHelpful(31, helpful: false), (helpful: false, count: 2));
    expect(await service.report(31, reason: 'spam', details: '  ads  '), 'Thanks. Our team will look at this review.');
    expect(api.lastReport, {'reason': 'spam', 'details': 'ads'});
  });

  testWidgets('mark a review helpful, and your own review has no actions', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(const ProductReviewsPage(product: _tee)));
    await tester.pumpAndSettle();

    expect(find.text('Salamat po!'), findsOneWidget);
    expect(find.text('Your review'), findsOneWidget);
    expect(find.text('Helpful (2)'), findsOneWidget);
    expect(find.text('Report'), findsOneWidget, reason: 'only on the other buyer’s review');

    await tester.tap(find.text('Helpful (2)'));
    await tester.pumpAndSettle();
    expect(find.text('Helpful (3)'), findsOneWidget);
    expect(api.votedHelpful, isTrue);

    await tester.tap(find.text('Helpful (3)'));
    await tester.pumpAndSettle();
    expect(find.text('Helpful (2)'), findsOneWidget);
  });

  testWidgets('report a review: a reason is required, then it shows as reported', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(const ProductReviewsPage(product: _tee)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Report'));
    await tester.pumpAndSettle();
    expect(find.text('Report this review'), findsOneWidget);
    await tester.tap(find.text('Send report'));
    await tester.pumpAndSettle();
    expect(find.text('Choose why you are reporting this review.'), findsOneWidget);
    expect(api.lastReport, isNull);

    await tester.tap(find.text('Spam or advertising'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).last, 'Links to another shop');
    await tester.tap(find.text('Send report'));
    await tester.pumpAndSettle();

    expect(api.lastReport, {'reason': 'spam', 'details': 'Links to another shop'});
    expect(find.text('Reported'), findsOneWidget);
    expect(find.text('Thanks. Our team will look at this review.'), findsOneWidget);
  });
}
