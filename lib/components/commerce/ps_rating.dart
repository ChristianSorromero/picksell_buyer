import 'package:flutter/material.dart';

import '../../core/theme/ps_colors.dart';
import '../../core/theme/ps_tokens.dart';
import '../../core/theme/ps_typography.dart';
import '../../format_utils.dart';
import '../../models/catalog.dart';
import '../shared/ps_card.dart';

/// Row of five stars; supports halves for averages. With [onChanged] it
/// becomes a 44pt-per-star input (rate order).
class PsRatingStars extends StatelessWidget {
  const PsRatingStars({super.key, required this.rating, this.size = 14, this.onChanged});

  final double rating;
  final double size;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${rating.toStringAsFixed(rating % 1 == 0 ? 0 : 1)} out of 5 stars',
      slider: onChanged != null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 5; i++)
            _star(
              rating >= i
                  ? Icons.star_rounded
                  : rating >= i - 0.5
                      ? Icons.star_half_rounded
                      : Icons.star_outline_rounded,
              rating >= i - 0.5,
              i,
            ),
        ],
      ),
    );
  }

  Widget _star(IconData icon, bool filled, int value) {
    final glyph = Icon(icon, size: size, color: filled ? PsColors.star : PsColors.border);
    if (onChanged == null) return glyph;
    return InkResponse(
      onTap: () => onChanged!(value),
      radius: 24,
      child: SizedBox.square(dimension: PsSize.minTap, child: Center(child: glyph)),
    );
  }
}

/// "★ 4.8 (2.4k)" — or nothing when a product has no reviews yet.
class PsRatingInline extends StatelessWidget {
  const PsRatingInline({super.key, required this.rating, this.count, this.trailing});

  final double? rating;
  final int? count;

  /// e.g. "· Mabuhay Gadgets"
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final r = rating;
    if (r == null && trailing == null) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (r != null) ...[
          const Icon(Icons.star_rounded, size: 15, color: PsColors.star),
          const SizedBox(width: 3),
          Text(r.toStringAsFixed(1), style: PsText.caption.copyWith(color: PsColors.textPrimary, fontWeight: FontWeight.w700)),
          if (count != null && count! > 0) Text(' (${compactCount(count!)})', style: PsText.caption),
        ],
        if (trailing != null)
          Flexible(
            child: Text(
              '${r != null ? ' · ' : ''}$trailing',
              style: PsText.caption.copyWith(fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }
}

/// COM-C03 Product Rating Summary — big average, review count and a bar
/// per star level, all from approved reviews.
class PsRatingSummary extends StatelessWidget {
  const PsRatingSummary({super.key, required this.summary});

  final RatingSummary summary;

  @override
  Widget build(BuildContext context) {
    final max = summary.distribution.values.fold<int>(0, (a, b) => a > b ? a : b);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 96,
          child: Column(
            children: [
              Text(
                summary.average?.toStringAsFixed(1) ?? '–',
                style: PsText.display.copyWith(fontSize: 44, fontWeight: FontWeight.w700, height: 1),
              ),
              const SizedBox(height: 4),
              Text('out of 5', style: PsText.caption),
              const SizedBox(height: 6),
              PsRatingStars(rating: summary.average ?? 0, size: 13),
            ],
          ),
        ),
        const SizedBox(width: PsSpace.md),
        Expanded(
          child: Column(
            children: [
              for (final star in [5, 4, 3, 2, 1])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      SizedBox(width: 14, child: Text('$star', style: PsText.caption.copyWith(fontWeight: FontWeight.w700))),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: max == 0 ? 0 : (summary.distribution[star] ?? 0) / max,
                            minHeight: 7,
                            color: PsColors.primary,
                            backgroundColor: PsColors.border,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 34,
                        child: Text('${summary.distribution[star] ?? 0}', textAlign: TextAlign.right, style: PsText.caption),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One buyer review.
class PsReviewCard extends StatelessWidget {
  const PsReviewCard({super.key, required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    final initials = review.reviewer.trim().isEmpty ? '?' : review.reviewer.trim()[0].toUpperCase();
    return PsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: PsColors.primarySoft,
                child: Text(initials, style: PsText.bodyStrong.copyWith(color: PsColors.primaryStrong)),
              ),
              const SizedBox(width: PsSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(review.reviewer, style: PsText.bodyStrong),
                    const SizedBox(height: 2),
                    PsRatingStars(rating: review.rating.toDouble(), size: 15),
                  ],
                ),
              ),
              if (review.createdAt != null) Text(formatDate(review.createdAt!), style: PsText.caption.copyWith(fontSize: 11.5)),
            ],
          ),
          if (review.variationLabel != null) ...[
            const SizedBox(height: PsSpace.sm),
            PsTag.muted('Variation: ${review.variationLabel}'),
          ],
          if (review.comment != null && review.comment!.trim().isNotEmpty) ...[
            const SizedBox(height: PsSpace.sm),
            Text(review.comment!, style: PsText.body.copyWith(height: 1.55)),
          ],
        ],
      ),
    );
  }
}
