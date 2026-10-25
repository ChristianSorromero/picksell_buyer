import 'package:flutter/material.dart';

import '../../core/theme/ps_colors.dart';
import '../../core/theme/ps_typography.dart';
import '../../format_utils.dart';

enum PsPriceSize { small, medium, large }

/// COM-C05 Price Display — sale price, struck-through original and an
/// optional "34% OFF" tag. Values always come from the API; nothing is
/// computed or invented here.
class PsPriceDisplay extends StatelessWidget {
  const PsPriceDisplay({
    super.key,
    required this.price,
    this.originalPrice,
    this.discountPercent,
    this.size = PsPriceSize.medium,
    this.accent = false,
    this.showDiscountTag = false,
  });

  final double price;
  final double? originalPrice;
  final int? discountPercent;
  final PsPriceSize size;

  /// Coral price (detail pages, cart) vs. dark (cards).
  final bool accent;
  final bool showDiscountTag;

  @override
  Widget build(BuildContext context) {
    final fontSize = switch (size) {
      PsPriceSize.small => 15.0,
      PsPriceSize.medium => 17.0,
      PsPriceSize.large => 26.0,
    };
    final hasOriginal = originalPrice != null && originalPrice! > price;

    return Semantics(
      label: hasOriginal ? '${formatPesoFixed(price)}, was ${formatPesoFixed(originalPrice!)}' : formatPesoFixed(price),
      excludeSemantics: true,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 2,
        children: [
          Text(
            size == PsPriceSize.large ? formatPesoFixed(price) : formatPeso(price),
            style: PsText.price.copyWith(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: accent ? PsColors.primary : PsColors.textPrimary,
            ),
          ),
          if (hasOriginal)
            Text(
              formatPeso(originalPrice!),
              style: PsText.caption.copyWith(
                fontSize: size == PsPriceSize.large ? 14 : 12,
                decoration: TextDecoration.lineThrough,
                color: PsColors.textHint,
              ),
            ),
          if (showDiscountTag && discountPercent != null && discountPercent! > 0)
            PsDiscountTag(percent: discountPercent!, inline: true),
        ],
      ),
    );
  }
}

/// COM-C06 Discount Tag — shown only when the API reports a discount.
class PsDiscountTag extends StatelessWidget {
  const PsDiscountTag({super.key, required this.percent, this.inline = false});

  final int percent;

  /// Inline "34% OFF" pill next to a price vs. corner ribbon "-25%".
  final bool inline;

  @override
  Widget build(BuildContext context) {
    if (percent <= 0) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.symmetric(horizontal: inline ? 6 : 8, vertical: inline ? 2 : 5),
      decoration: BoxDecoration(
        color: inline ? PsColors.primarySoft : PsColors.primary,
        borderRadius: inline
            ? BorderRadius.circular(4)
            : const BorderRadius.only(topLeft: Radius.circular(12), bottomRight: Radius.circular(8)),
      ),
      child: Text(
        inline ? '$percent% OFF' : '-$percent%',
        style: PsText.badge.copyWith(
          color: inline ? PsColors.primaryStrong : PsColors.onPrimary,
          fontSize: inline ? 11 : 12,
        ),
      ),
    );
  }
}
