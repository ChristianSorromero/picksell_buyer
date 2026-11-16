import 'package:flutter/material.dart';

import '../../core/theme/ps_colors.dart';
import '../../core/theme/ps_tokens.dart';
import '../../core/theme/ps_typography.dart';
import '../../models/catalog.dart';
import '../shared/ps_buttons.dart';
import '../shared/ps_card.dart';
import 'ps_product_image.dart';

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
  const PsSellerAvatar({super.key, required this.name, this.size = 48, this.logo});

  final String name;
  final double size;

  /// The store's logo; the initials show until it loads or when there is none.
  final String? logo;

  @override
  Widget build(BuildContext context) {
    final letters = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(2).map((w) => w[0].toUpperCase()).join();
    final initials = Text(letters.isEmpty ? '?' : letters, style: PsText.bodyStrong.copyWith(fontSize: size * 0.34));
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: PsColors.surfaceMuted, borderRadius: BorderRadius.circular(size * 0.25)),
      // Same loader as product photos (web CORS, tunnel header, disk cache),
      // so a logo that exists always shows; the initials cover the rest.
      child: PsProductImage(url: logo, fit: BoxFit.cover, placeholder: Center(child: initials), semanticLabel: '$name logo'),
    );
  }
}

/// COM-C04 Seller Summary Card — identity, verification and trust signals
/// with a "View Store" action. The whole card (logo, name, details) opens
/// the same store as the button.
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
      onTap: onVisit,
      child: Row(
        children: [
          Semantics(
            label: '${seller.name} store logo',
            image: true,
            child: PsSellerAvatar(name: seller.name, logo: seller.logo, size: 52),
          ),
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
          if (onVisit != null) PsSecondaryButton.outlined(label: 'View Store', onPressed: onVisit),
        ],
      ),
    );
  }
}
