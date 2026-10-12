import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app_colors.dart';
import '../app_text_styles.dart';
import '../format_utils.dart';
import '../models/product.dart';
import '../widgets/page_dots.dart';
import '../widgets/primary_button.dart';
import '../widgets/product_image.dart';

/// Template layout for viewing a single product:
/// image gallery, name, rating, price, stock, seller, variants,
/// quantity selector, description and a sticky Add to Cart / Buy Now bar.
///
/// Feed it any [Product] — hardcoded now, API data later.
class ProductDetailsPage extends StatefulWidget {
  const ProductDetailsPage({
    super.key,
    required this.product,
    this.isFavorite = false,
    this.onFavoriteChanged,
    this.onAddToCart,
  });

  final Product product;
  final bool isFavorite;
  final ValueChanged<bool>? onFavoriteChanged;

  /// Called with the chosen quantity when the buyer taps "Add to Cart".
  final ValueChanged<int>? onAddToCart;

  @override
  State<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends State<ProductDetailsPage> {
  late bool _favorite = widget.isFavorite;
  late int _quantity = widget.product.stock > 0 ? 1 : 0;
  late final Map<String, String> _selectedVariants = {
    for (final group in widget.product.variantGroups)
      if (group.options.isNotEmpty) group.name: group.options.first,
  };
  int _imageIndex = 0;

  static const double _galleryHeight = 340;

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String get _variantSummary => _selectedVariants.values.join(', ');

  void _addToCart() {
    widget.onAddToCart?.call(_quantity);
    _showSnack(
      'Added $_quantity × ${widget.product.name}'
      '${_variantSummary.isEmpty ? '' : ' ($_variantSummary)'}',
    );
  }

  void _buyNow() => _showSnack('Checkout coming soon');

  void _toggleFavorite() {
    setState(() => _favorite = !_favorite);
    widget.onFavoriteChanged?.call(_favorite);
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final imageCount = product.images.isEmpty ? 3 : product.images.length;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Stack(
                    children: [
                      // Gallery
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: _galleryHeight,
                        child: Stack(
                          children: [
                            PageView.builder(
                              itemCount: imageCount,
                              onPageChanged: (i) =>
                                  setState(() => _imageIndex = i),
                              itemBuilder: (_, i) => ProductImage(
                                url: product.images.isEmpty
                                    ? null
                                    : product.images[i],
                                seed: product.id + i,
                                iconSize: 64,
                              ),
                            ),
                            Positioned(
                              bottom: 40,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: PageDots(
                                  currentIndex: _imageIndex,
                                  count: imageCount,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Info sheet overlapping the gallery
                      Column(
                        children: [
                          const SizedBox(height: _galleryHeight - 24),
                          _buildInfo(product),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              _buildBottomBar(product),
            ],
          ),
          // Floating back + favorite buttons
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _CircleButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                    _CircleButton(
                      icon: _favorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      iconColor: _favorite
                          ? AppColors.primary
                          : AppColors.textPrimary,
                      onTap: _toggleFavorite,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────── INFO ─────────────────────────────
  Widget _buildInfo(Product product) {
    final discount = product.discountPercent;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            product.name,
            style: GoogleFonts.poppins(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              height: 1.25,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.star_rounded, size: 18, color: AppColors.star),
              const SizedBox(width: 4),
              Text(
                product.rating.toStringAsFixed(1),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text('  ·  ${product.soldLabel}', style: AppTextStyles.small),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                formatPeso(product.price),
                style: GoogleFonts.poppins(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              if (product.originalPrice != null) ...[
                const SizedBox(width: 10),
                Text(
                  formatPeso(product.originalPrice!),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.textHint,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ],
              if (discount != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '-$discount%',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          _buildStockBadge(product),
          const Divider(height: 36, color: AppColors.border),
          _buildSeller(product),
          const Divider(height: 36, color: AppColors.border),
          for (final group in product.variantGroups) _buildVariantGroup(group),
          _buildQuantity(product),
          const Divider(height: 36, color: AppColors.border),
          Text(
            'Product Description',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            product.description.isEmpty
                ? 'No description provided by the seller.'
                : product.description,
            style: AppTextStyles.body.copyWith(height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildStockBadge(Product product) {
    final Color color;
    final String text;
    if (product.stock <= 0) {
      color = AppColors.textSecondary;
      text = 'Out of stock';
    } else if (product.stock <= 10) {
      color = AppColors.primary;
      text = 'Only ${product.stock} left';
    } else {
      color = AppColors.success;
      text = '${product.stock} in stock';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeller(Product product) {
    return Row(
      children: [
        SizedBox(
          width: 46,
          height: 46,
          child: ProductImage(
            seed: product.id + 2,
            borderRadius: BorderRadius.circular(23),
            iconSize: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      product.sellerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (product.isVerifiedSeller) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.verified_rounded,
                      size: 14,
                      color: AppColors.verified,
                    ),
                  ],
                ],
              ),
              if (product.sellerLocation.isNotEmpty)
                Text(
                  product.sellerLocation,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.small.copyWith(fontSize: 11.5),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: () => _showSnack('Shop page coming soon'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(
            'Visit Shop',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildVariantGroup(ProductVariantGroup group) {
    final selected = _selectedVariants[group.name];

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                group.name,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              if (selected != null)
                Text('  $selected', style: AppTextStyles.small),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in group.options)
                GestureDetector(
                  onTap: () => setState(
                    () => _selectedVariants[group.name] = option,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: option == selected
                          ? AppColors.primaryLight
                          : AppColors.inputFill,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: option == selected
                            ? AppColors.primary
                            : Colors.transparent,
                        width: 1.3,
                      ),
                    ),
                    child: Text(
                      option,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: option == selected
                            ? AppColors.primary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuantity(Product product) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quantity',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                product.inStock
                    ? '${product.stock} available'
                    : 'Currently unavailable',
                style: AppTextStyles.small.copyWith(fontSize: 11.5),
              ),
            ],
          ),
        ),
        _QuantityStepper(
          quantity: _quantity,
          max: product.stock,
          onChanged: (value) => setState(() => _quantity = value),
        ),
      ],
    );
  }

  // ───────────────────────────── BOTTOM BAR ─────────────────────────────
  Widget _buildBottomBar(Product product) {
    final total = product.price * _quantity;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Total', style: AppTextStyles.small.copyWith(fontSize: 11)),
                Text(
                  formatPeso(total),
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: product.inStock ? _addToCart : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(
                      color: product.inStock
                          ? AppColors.primary
                          : AppColors.border,
                      width: 1.3,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Add to Cart',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: PrimaryButton(
                label: 'Buy Now',
                onPressed: product.inStock ? _buyNow : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════ PRIVATE WIDGETS ═══════════════════════════

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.onTap,
    this.iconColor = AppColors.textPrimary,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 18, color: iconColor),
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.quantity,
    required this.max,
    required this.onChanged,
  });

  final int quantity;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            icon: Icons.remove_rounded,
            onTap: quantity > 1 ? () => onChanged(quantity - 1) : null,
          ),
          SizedBox(
            width: 40,
            child: Center(
              child: Text(
                '$quantity',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          _StepButton(
            icon: Icons.add_rounded,
            onTap: quantity < max ? () => onChanged(quantity + 1) : null,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Icon(
          icon,
          size: 20,
          color: onTap == null ? AppColors.textHint : AppColors.textPrimary,
        ),
      ),
    );
  }
}
