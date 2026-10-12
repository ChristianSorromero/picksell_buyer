import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app_colors.dart';
import '../app_text_styles.dart';
import '../format_utils.dart';
import '../models/cart_item.dart';
import '../services/cart_service.dart';
import '../widgets/product_image.dart';

/// The buyer's cart, grouped by seller, with per-item and per-store
/// selection, quantity steppers, and a checkout summary.
///
/// Pass [onBack] to show a back button (e.g. when pushed on top of another
/// page). Leave it null to use this as an embedded tab, like the "Cart" tab
/// on the buyer dashboard's bottom nav — it already sits inside a Scaffold
/// there, so no back button or extra Scaffold is drawn.
class CartPage extends StatefulWidget {
  const CartPage({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  bool _editing = false;

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: CartService.instance,
      builder: (context, _) {
        final cart = CartService.instance;
        final grouped = cart.groupedBySeller;

        return SafeArea(
          top: widget.onBack != null,
          bottom: false,
          child: Column(
            children: [
              _buildHeader(cart.itemCount),
              Expanded(
                child: cart.isEmpty
                    ? _buildEmpty()
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                        children: [
                          for (final entry in grouped.entries) ...[
                            _StoreSection(
                              sellerName: entry.key,
                              items: entry.value,
                              editing: _editing,
                            ),
                            const SizedBox(height: 18),
                          ],
                        ],
                      ),
              ),
              if (!cart.isEmpty) _buildSummary(cart),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.shopping_bag_outlined,
            size: 56,
            color: AppColors.textHint,
          ),
          const SizedBox(height: 12),
          Text('Your cart is empty', style: AppTextStyles.body),
        ],
      ),
    );
  }

  Widget _buildHeader(int itemCount) {
    return Padding(
      padding: EdgeInsets.fromLTRB(widget.onBack != null ? 12 : 20, 8, 20, 0),
      child: Row(
        children: [
          if (widget.onBack != null)
            IconButton(
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              color: AppColors.textPrimary,
            )
          else
            const SizedBox(width: 0),
          Text(
            'My Cart',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          if (itemCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$itemCount items',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          const Spacer(),
          if (!CartService.instance.isEmpty)
            GestureDetector(
              onTap: () => setState(() => _editing = !_editing),
              behavior: HitTestBehavior.opaque,
              child: Text(
                _editing ? 'Done' : 'Edit',
                style: AppTextStyles.link.copyWith(fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummary(CartService cart) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => _showSnack('Vouchers coming soon'),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.local_offer_outlined,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Vouchers & Promo Code',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppColors.textHint,
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 20, color: AppColors.border),
          _SummaryRow(label: 'Subtotal', value: formatPeso(cart.selectedSubtotal)),
          const SizedBox(height: 6),
          _SummaryRow(label: 'Shipping', value: 'Free', valueColor: AppColors.success),
          const SizedBox(height: 10),
          _SummaryRow(
            label: 'Total',
            value: formatPeso(cart.selectedSubtotal),
            emphasize: true,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: cart.selectedCount == 0
                  ? null
                  : () => _showSnack('Checkout coming soon'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.dotInactive,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Proceed to Checkout', style: AppTextStyles.button),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: emphasize ? 14 : 12.5,
            fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: emphasize ? 17 : 13,
            fontWeight: FontWeight.w700,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _StoreSection extends StatelessWidget {
  const _StoreSection({
    required this.sellerName,
    required this.items,
    required this.editing,
  });

  final String sellerName;
  final List<CartItem> items;
  final bool editing;

  @override
  Widget build(BuildContext context) {
    final cart = CartService.instance;
    final fullySelected = cart.isSellerFullySelected(sellerName);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _CartCheckbox(
                value: fullySelected,
                onChanged: (value) => cart.toggleSeller(sellerName, value),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.storefront_rounded, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  sellerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20, color: AppColors.border),
          for (int i = 0; i < items.length; i++) ...[
            _CartItemRow(item: items[i], editing: editing),
            if (i != items.length - 1)
              const Divider(height: 20, color: AppColors.border),
          ],
        ],
      ),
    );
  }
}

class _CartItemRow extends StatelessWidget {
  const _CartItemRow({required this.item, required this.editing});

  final CartItem item;
  final bool editing;

  @override
  Widget build(BuildContext context) {
    final cart = CartService.instance;
    final product = item.product;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CartCheckbox(
          value: item.isSelected,
          onChanged: (value) => cart.toggleSelected(item, value),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 56,
          height: 56,
          child: ProductImage(
            url: product.images.isEmpty ? null : product.images.first,
            seed: product.id,
            borderRadius: BorderRadius.circular(10),
            iconSize: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              if (item.selectedVariant != null) ...[
                const SizedBox(height: 3),
                Text(
                  item.selectedVariant!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.small.copyWith(fontSize: 11),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    formatPeso(product.price),
                    style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  if (editing)
                    GestureDetector(
                      onTap: () => cart.removeItem(item),
                      behavior: HitTestBehavior.opaque,
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        size: 20,
                        color: AppColors.primary,
                      ),
                    )
                  else
                    _QuantityStepper(item: item),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context) {
    final cart = CartService.instance;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepperButton(
            icon: Icons.remove_rounded,
            onTap: () => cart.updateQuantity(item, item.quantity - 1),
          ),
          SizedBox(
            width: 24,
            child: Text(
              '${item.quantity}',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          _StepperButton(
            icon: Icons.add_rounded,
            onTap: () => cart.updateQuantity(item, item.quantity + 1),
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 26,
        height: 26,
        child: Icon(icon, size: 14, color: AppColors.textPrimary),
      ),
    );
  }
}

class _CartCheckbox extends StatelessWidget {
  const _CartCheckbox({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: value ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: value ? AppColors.primary : AppColors.border,
            width: 1.4,
          ),
        ),
        child: value
            ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
            : null,
      ),
    );
  }
}
