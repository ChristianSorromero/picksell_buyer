import 'package:flutter/material.dart';

import '../../../components/components.dart';
import '../../../models/catalog.dart';
import '../../../services/catalog_service.dart';

enum _ReviewFilter { all, five, four, low, comments }

/// COM-C03 Product Reviews: summary bars + filterable review list.
class ProductReviewsPage extends StatefulWidget {
  const ProductReviewsPage({super.key, required this.product});

  final Product product;

  @override
  State<ProductReviewsPage> createState() => _ProductReviewsPageState();
}

class _ProductReviewsPageState extends State<ProductReviewsPage> {
  final _catalog = CatalogService();
  _ReviewFilter _filter = _ReviewFilter.all;
  Key _key = UniqueKey();

  Future<ReviewPage> _load() => _catalog.reviews(
        widget.product.id,
        rating: switch (_filter) {
          _ReviewFilter.five => 5,
          _ReviewFilter.four => 4,
          _ => null,
        },
        withComments: _filter == _ReviewFilter.comments,
      );

  @override
  Widget build(BuildContext context) {
    return PsAppShell(
      topBar: const PsTopBar(title: 'Product Reviews'),
      body: PsAsyncView<ReviewPage>(
        key: _key,
        load: _load,
        builder: (context, page, _) {
          final reviews = _filter == _ReviewFilter.low ? page.reviews.where((r) => r.rating <= 3).toList() : page.reviews;
          return ListView(
            padding: const EdgeInsets.all(PsSpace.gutter),
            children: [
              PsRatingSummary(summary: page.summary),
              const SizedBox(height: PsSpace.sm),
              Text('${page.summary.count} ${page.summary.count == 1 ? 'Review' : 'Reviews'}', style: PsText.bodyStrong),
              const SizedBox(height: PsSpace.sm),
              Wrap(
                spacing: PsSpace.xs,
                runSpacing: PsSpace.xs,
                children: [
                  for (final (f, label) in const [
                    (_ReviewFilter.all, 'All'),
                    (_ReviewFilter.five, '5 Stars'),
                    (_ReviewFilter.four, '4 Stars'),
                    (_ReviewFilter.low, '3 Stars & below'),
                    (_ReviewFilter.comments, 'With Comments'),
                  ])
                    ChoiceChip(
                      label: Text(label),
                      selected: _filter == f,
                      showCheckmark: false,
                      selectedColor: PsColors.textPrimary,
                      labelStyle: PsText.caption.copyWith(fontWeight: FontWeight.w600, color: _filter == f ? Colors.white : PsColors.textPrimary),
                      onSelected: (_) => setState(() {
                        _filter = f;
                        _key = UniqueKey();
                      }),
                    ),
                ],
              ),
              const SizedBox(height: PsSpace.md),
              if (reviews.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(PsSpace.xl),
                  child: Text('No reviews match this filter.', textAlign: TextAlign.center, style: PsText.bodyMuted),
                ),
              for (final r in reviews) ...[PsReviewCard(review: r), const SizedBox(height: PsSpace.sm)],
            ],
          );
        },
      ),
    );
  }
}
