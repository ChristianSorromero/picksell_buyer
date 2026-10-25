import 'package:flutter/material.dart';

import '../../core/theme/ps_colors.dart';
import '../../core/theme/ps_tokens.dart';
import '../../core/theme/ps_typography.dart';
import '../../format_utils.dart';
import 'ps_product_image.dart';
import 'ps_seller_card.dart';

/// One product row inside an order or checkout summary.
class PsOrderLineRow extends StatelessWidget {
  const PsOrderLineRow({
    super.key,
    required this.name,
    required this.image,
    required this.quantity,
    required this.unitPrice,
    this.variationLabel,
    this.onTap,
    this.thumbSize = 64,
  });

  final String name;
  final String? image;
  final int quantity;
  final double unitPrice;
  final String? variationLabel;
  final VoidCallback? onTap;
  final double thumbSize;

  @override
  Widget build(BuildContext context) {
    final qty = quantity > 1 ? 'Qty: ${quantity}x (${formatPesoFixed(unitPrice)} ea)' : 'Qty: 1x';
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: PsSpace.xs),
        child: Row(
          children: [
            PsThumbnail(url: image, size: thumbSize),
            const SizedBox(width: PsSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: PsText.bodyStrong, maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (variationLabel != null) Text(variationLabel!, style: PsText.caption),
                  Text(qty, style: PsText.caption),
                  const SizedBox(height: 2),
                  Text(formatPesoFixed(unitPrice * quantity), style: PsText.bodyStrong),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// COM-C19 Order Summary — a seller's items in one compact block.
class PsOrderSummary extends StatelessWidget {
  const PsOrderSummary({
    super.key,
    required this.sellerName,
    required this.lines,
    this.verified = false,
    this.footer,
    this.headerTrailing,
  });

  final String sellerName;
  final bool verified;
  final List<PsOrderLineRow> lines;
  final Widget? footer;

  /// e.g. the order's status badge.
  final Widget? headerTrailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PsColors.surface,
        borderRadius: PsRadius.card,
        border: Border.all(color: PsColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(PsSpace.md, PsSpace.sm, PsSpace.md, PsSpace.sm),
            child: Row(
              children: [
                const Icon(Icons.storefront_rounded, size: 18),
                const SizedBox(width: 8),
                Flexible(child: Text(sellerName, style: PsText.bodyStrong, overflow: TextOverflow.ellipsis)),
                if (verified) ...[const SizedBox(width: 4), const PsVerifiedBadge(size: 15)],
                if (headerTrailing != null) ...[const Spacer(), headerTrailing!],
              ],
            ),
          ),
          const Divider(),
          for (var i = 0; i < lines.length; i++) ...[
            if (i > 0) const Divider(),
            Padding(padding: const EdgeInsets.symmetric(horizontal: PsSpace.md, vertical: 4), child: lines[i]),
          ],
          if (footer != null) ...[const Divider(), Padding(padding: const EdgeInsets.all(PsSpace.md), child: footer!)],
        ],
      ),
    );
  }
}
