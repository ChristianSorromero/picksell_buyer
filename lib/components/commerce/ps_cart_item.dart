import 'package:flutter/material.dart';

import '../../core/theme/ps_colors.dart';
import '../../core/theme/ps_tokens.dart';
import '../../core/theme/ps_typography.dart';
import '../../format_utils.dart';
import '../../models/cart.dart';
import '../shared/ps_card.dart';
import 'ps_product_image.dart';
import 'ps_quantity_stepper.dart';
import 'ps_seller_card.dart';

/// Coral square checkbox used by cart selection (Figma COM-C12).
class PsCheck extends StatelessWidget {
  const PsCheck({super.key, required this.value, required this.onChanged, this.label, this.partial = false});

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;

  /// Some (not all) children selected.
  final bool partial;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    final on = value || partial;
    return Semantics(
      checked: value,
      enabled: enabled,
      label: label,
      child: InkResponse(
        onTap: enabled ? () => onChanged!(!value) : null,
        radius: 22,
        child: SizedBox.square(
          dimension: PsSize.minTap,
          child: Center(
            child: AnimatedContainer(
              duration: PsMotion.fast,
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: !enabled ? PsColors.surfaceMuted : (on ? PsColors.primary : PsColors.surface),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: !enabled ? PsColors.border : (on ? PsColors.primary : PsColors.textHint), width: 1.6),
              ),
              child: on
                  ? Icon(partial && !value ? Icons.remove_rounded : Icons.check_rounded, size: 16, color: Colors.white)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// COM-C12 Cart Item — selection, image, variation, price, quantity, and
/// any stock problem the server reported for this line.
class PsCartItemTile extends StatelessWidget {
  const PsCartItemTile({
    super.key,
    required this.line,
    required this.selected,
    required this.onSelected,
    required this.onQuantity,
    this.onTap,
    this.onEditVariation,
    this.busy = false,
    this.editing = false,
    this.maxQuantity = 10,
  });

  final CartLine line;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final ValueChanged<int> onQuantity;
  final VoidCallback? onTap;
  final VoidCallback? onEditVariation;
  final bool busy;

  /// Edit mode: selection is for removal, so unavailable lines can be ticked.
  final bool editing;
  final int maxQuantity;

  @override
  Widget build(BuildContext context) {
    final issue = line.issue;
    final selectable = editing || line.purchasable;
    final stockCap = line.availableStock < maxQuantity ? line.availableStock : maxQuantity;

    return PsCard(
      padding: const EdgeInsets.fromLTRB(0, PsSpace.sm, PsSpace.sm, PsSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          PsCheck(
            value: selected && selectable,
            label: 'Select ${line.product.name}',
            onChanged: selectable ? onSelected : null,
          ),
          GestureDetector(onTap: onTap, child: PsThumbnail(url: line.product.image, size: 84)),
          const SizedBox(width: PsSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: onTap,
                  child: Text(line.product.name, style: PsText.bodyStrong.copyWith(fontSize: 15), maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
                if (line.variationLabel != null)
                  InkWell(
                    onTap: onEditVariation,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(child: Text(line.variationLabel!, style: PsText.caption, maxLines: 1, overflow: TextOverflow.ellipsis)),
                          if (onEditVariation != null) const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: PsColors.textMuted),
                        ],
                      ),
                    ),
                  ),
                if (issue != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      issue == CartLineIssue.insufficientStock && line.availableStock > 0
                          ? 'Only ${line.availableStock} left — lower the quantity.'
                          : issue.message,
                      style: PsText.caption.copyWith(color: PsColors.error, fontWeight: FontWeight.w600),
                    ),
                  ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        formatPesoFixed(line.unitPrice),
                        style: PsText.price.copyWith(color: issue == null ? PsColors.primary : PsColors.textHint),
                      ),
                    ),
                    if (busy)
                      const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    else if (line.availableStock > 0)
                      PsQuantityStepper(
                        compact: true,
                        value: line.quantity,
                        max: stockCap < line.quantity ? line.quantity : stockCap,
                        onChanged: onQuantity,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// COM-C13 Seller Cart Group header: seller checkbox, name, verified badge.
class PsSellerGroupHeader extends StatelessWidget {
  const PsSellerGroupHeader({
    super.key,
    required this.name,
    required this.verified,
    required this.allSelected,
    required this.someSelected,
    required this.onSelected,
    this.onTap,
  });

  final String name;
  final bool verified;
  final bool allSelected;
  final bool someSelected;
  final ValueChanged<bool>? onSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        PsCheck(value: allSelected, partial: someSelected, label: 'Select all from $name', onChanged: onSelected),
        Flexible(
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: PsSpace.xs),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.storefront_outlined, size: 18),
                  const SizedBox(width: 6),
                  Flexible(child: Text(name, style: PsText.bodyStrong.copyWith(fontSize: 15), overflow: TextOverflow.ellipsis)),
                  if (verified) ...[const SizedBox(width: 4), const PsVerifiedBadge()],
                  if (onTap != null) const Icon(Icons.chevron_right_rounded, size: 18, color: PsColors.textMuted),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// "Shipping: ₱45.00 (Picksell Standard)" + "Voucher ₱50 off applied" under a group.
class PsSellerGroupFooter extends StatelessWidget {
  const PsSellerGroupFooter({super.key, required this.shippingFee, this.shippingName, this.discount = 0});

  final double shippingFee;
  final String? shippingName;
  final double discount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(PsSpace.xs, PsSpace.xs, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Shipping: ${formatPesoFixed(shippingFee)}${shippingName == null ? '' : ' ($shippingName)'}',
            style: PsText.caption,
          ),
          if (discount > 0)
            Text('Voucher: ${formatPesoFixed(discount)} off applied',
                style: PsText.caption.copyWith(color: PsColors.primaryStrong, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
