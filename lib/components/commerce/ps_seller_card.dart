import 'package:flutter/material.dart';

import '../../core/theme/ps_colors.dart';
import '../../core/theme/ps_tokens.dart';
import '../../core/theme/ps_typography.dart';
import '../../models/catalog.dart';
import '../shared/ps_buttons.dart';
import '../shared/ps_card.dart';

/// Verified check next to a seller name.
class PsVerifiedBadge extends StatelessWidget {
  const PsVerifiedBadge({super.key, this.size = 16});

  final double size;

  @override
  Widget build(BuildContext context) =>
      Semantics(label: 'Verified seller', child: Icon(Icons.verified_rounded, size: size, color: PsColors.info));
}

/// Seller avatar from the store initials.
class PsSellerAvatar extends StatelessWidget {
  const PsSellerAvatar({super.key, required this.name, this.size = 48});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final letters = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(2).map((w) => w[0].toUpperCase()).join();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: PsColors.surfaceMuted, borderRadius: BorderRadius.circular(size * 0.25)),
      child: Text(letters.isEmpty ? '?' : letters, style: PsText.bodyStrong.copyWith(fontSize: size * 0.34)),
    );
  }
}

/// COM-C04 Seller Summary Card — identity, verification and trust signals
/// with a "Visit Store" action.
class PsSellerCard extends StatelessWidget {
  const PsSellerCard({super.key, required this.seller, this.onVisit});

  final SellerSummary seller;
  final VoidCallback? onVisit;

  @override
  Widget build(BuildContext context) {
    final trust = <String>[
      if (seller.positiveRate != null) '${seller.positiveRate}% Positive Feedback',
      if (seller.rating != null) '★ ${seller.rating!.toStringAsFixed(1)}',
      if (seller.productCount > 0) '${seller.productCount} products',
    ];

    return PsCard(
      child: Row(
        children: [
          PsSellerAvatar(name: seller.name),
          const SizedBox(width: PsSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(seller.name, style: PsText.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    if (seller.verified) ...[const SizedBox(width: 4), const PsVerifiedBadge()],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  trust.isEmpty ? (seller.location.isEmpty ? 'New on Picksell' : seller.location) : trust.join(' · '),
                  style: PsText.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (onVisit != null) PsSecondaryButton.outlined(label: 'Visit Store', onPressed: onVisit),
        ],
      ),
    );
  }
}
