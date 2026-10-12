import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'notifications_page.dart';
import 'profile_page.dart';
import '../app_colors.dart';
import '../app_text_styles.dart';
import '../models/product.dart';
import '../page_transitions.dart';
import '../services/cart_service.dart';
import '../services/product_service.dart';
import '../widgets/page_dots.dart';
import '../widgets/product_card.dart';
import '../widgets/product_image.dart';
import 'cart_page.dart';
import 'chats_page.dart';
import 'product_details.dart';

class _Category {
  const _Category(this.name, this.icon);
  final String name;
  final IconData icon;
}

/// `name` must match `Product.category`.
const List<_Category> _categories = [
  _Category('Fashion', Icons.checkroom_rounded),
  _Category('Electronics', Icons.laptop_mac_rounded),
  _Category('Sports', Icons.sports_basketball_rounded),
  _Category('Home', Icons.home_rounded),
  _Category('Beauty', Icons.spa_rounded),
];

class _BannerData {
  const _BannerData(this.title);
  final String title;
}

const List<_BannerData> _banners = [
  _BannerData('Mega Sale up to 50% off'),
  _BannerData('New arrivals from top sellers'),
  _BannerData('Free shipping on orders ₱999+'),
];

class BuyerDashboardPage extends StatefulWidget {
  const BuyerDashboardPage({super.key});

  @override
  State<BuyerDashboardPage> createState() => _BuyerDashboardPageState();
}

class _BuyerDashboardPageState extends State<BuyerDashboardPage> {
  static const _tabLabels = ['Home', 'Search', 'Wishlist', 'Cart', 'Profile'];

  int _tab = 0;
  int _bannerIndex = 0;
  int _categoryIndex = -1;
  String _query = '';

  List<Product> _products = [];
  bool _productsLoading = false;
  final _productService = ProductService();

  final Set<int> _favorites = {};

  final PageController _bannerController = PageController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_bannerController.hasClients) return;
      final next = (_bannerIndex + 1) % _banners.length;
      _bannerController.animateToPage(
        next,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() => _productsLoading = true);
    final category = _categoryIndex >= 0 && _categoryIndex < _categories.length
        ? _categories[_categoryIndex].name
        : null;
    final results = await _productService.getProducts(
      category: category,
      search: _query.trim().isEmpty ? null : _query.trim(),
    );
    if (mounted) setState(() { _products = results; _productsLoading = false; });
  }

  List<Product> get _visibleProducts => _products;

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _toggleFavorite(int id, bool value) {
    setState(() => value ? _favorites.add(id) : _favorites.remove(id));
  }

  void _addToCart(Product product, int quantity) {
    if (!product.inStock) {
      _showSnack('${product.name} is out of stock');
      return;
    }
    CartService.instance.addProduct(product, quantity);
    _showSnack('Added to cart');
  }

  void _openNotifications() {
  Navigator.of(context).push(fadeRoute(const NotificationsPage()));
}

  void _openProduct(Product product) {
    Navigator.of(context).push(
      fadeRoute(
        ProductDetailsPage(
          product: product,
          isFavorite: _favorites.contains(product.id),
          onFavoriteChanged: (value) => _toggleFavorite(product.id, value),
          onAddToCart: (quantity) =>
              CartService.instance.addProduct(product, quantity),
        ),
      ),
    );
  }

  void _openChats() {
    Navigator.of(context).push(fadeRoute(const ChatsPage()));
  }

  // ───────────────────────────── BUILD ─────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: _buildBody(),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBody() {
    switch (_tab) {
      case 0:
        return _buildHome();
      case 3:
        return const CartPage();
      case 4:
        return const ProfilePage();
      default:
        return _buildComingSoon();
    }
  }

  Widget _buildComingSoon() {
    return Center(
      child: Text(
        '${_tabLabels[_tab]} coming soon',
        style: AppTextStyles.body,
      ),
    );
  }

  Widget _buildHome() {
    final products = _visibleProducts;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildHeader()),
        SliverToBoxAdapter(child: _buildSearchBar()),
        SliverToBoxAdapter(child: _buildBanners()),
        SliverToBoxAdapter(
          child: _SectionHeader(
            title: 'Categories',
            actionLabel: 'See All',
            onAction: () => _showSnack('All categories coming soon'),
          ),
        ),
        SliverToBoxAdapter(child: _buildCategories()),
        SliverToBoxAdapter(
          child: _SectionHeader(
            title: 'Recommended for You',
            onAction: () {},
          ),
        ),
        if (_productsLoading)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            ),
          )
        else if (products.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text('No products found', style: AppTextStyles.body),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 18,
                crossAxisSpacing: 14,
                mainAxisExtent: 290,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final product = products[index];
                  return ProductCard(
                    product: product,
                    isFavorite: _favorites.contains(product.id),
                    onTap: () => _openProduct(product),
                    onFavoriteTap: () => _toggleFavorite(
                      product.id,
                      !_favorites.contains(product.id),
                    ),
                    onAddToCart: () => _addToCart(product, 1),
                  );
                },
                childCount: products.length,
              ),
            ),
          ),
      ],
    );
  }

  // ───────────────────────────── HEADER ─────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Row(
        children: [
          // Replace with the logo image when ready.
          Text.rich(
            TextSpan(
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
              children: const [
                TextSpan(
                  text: 'Pick',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                TextSpan(
                  text: 'sell',
                  style: TextStyle(color: AppColors.primary),
                ),
              ],
            ),
          ),
          const Spacer(),
          _HeaderIconButton(
            icon: Icons.notifications_none_rounded,
            showDot: true,
            onTap: _openNotifications,   // was: () => _showSnack('Notifications coming soon')
          ),
          const SizedBox(width: 10),
          _HeaderIconButton(
            icon: Icons.chat_bubble_outline_rounded,
            showDot: true,
            onTap: _openChats,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (value) { setState(() => _query = value); _loadProducts(); },
              style: AppTextStyles.input,
              cursorColor: AppColors.primary,
              decoration: InputDecoration(
                hintText: 'Search products',
                hintStyle: AppTextStyles.hint,
                filled: true,
                fillColor: AppColors.inputFill,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 44),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Material(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _showSnack('Filters coming soon'),
              child: const SizedBox(
                width: 46,
                height: 46,
                child: Icon(Icons.tune_rounded, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────── BANNERS ─────────────────────────────
  Widget _buildBanners() {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        children: [
          SizedBox(
            height: 160,
            child: PageView.builder(
              controller: _bannerController,
              itemCount: _banners.length,
              onPageChanged: (i) => setState(() => _bannerIndex = i),
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _BannerCard(
                  data: _banners[i],
                  seed: i + 1,
                  onShopNow: () => _showSnack('Promo coming soon'),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          PageDots(currentIndex: _bannerIndex, count: _banners.length),
        ],
      ),
    );
  }

  // ───────────────────────────── CATEGORIES ─────────────────────────────
  Widget _buildCategories() {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (_, i) {
          final category = _categories[i];
          final selected = i == _categoryIndex && _categoryIndex >= 0;
          return GestureDetector(
            onTap: () {
              setState(() => _categoryIndex = _categoryIndex == i ? -1 : i);
              _loadProducts();
            },
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: 68,
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected
                          ? AppColors.primaryLight
                          : AppColors.inputFill,
                      border: Border.all(
                        color:
                            selected ? AppColors.primary : Colors.transparent,
                        width: 1.3,
                      ),
                    ),
                    child: Icon(
                      category.icon,
                      size: 24,
                      color: selected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    category.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ───────────────────────────── BOTTOM NAV ─────────────────────────────
  Widget _cartIcon({required bool active}) {
    final count = CartService.instance.itemCount;
    return Badge(
      isLabelVisible: count > 0,
      label: Text('$count'),
      backgroundColor: AppColors.primary,
      textColor: Colors.white,
      child: Icon(
        active ? Icons.shopping_bag_rounded : Icons.shopping_bag_outlined,
      ),
    );
  }

  Widget _buildBottomNav() {
    return AnimatedBuilder(
      animation: CartService.instance,
      builder: (context, _) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: BottomNavigationBar(
            currentIndex: _tab,
            onTap: (i) => setState(() => _tab = i),
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            elevation: 0,
            selectedItemColor: AppColors.primary,
            unselectedItemColor: AppColors.textHint,
            selectedFontSize: 11,
            unselectedFontSize: 11,
            selectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
            unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500),
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.search_rounded),
                label: 'Search',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.favorite_border_rounded),
                activeIcon: Icon(Icons.favorite_rounded),
                label: 'Wishlist',
              ),
              BottomNavigationBarItem(
                icon: _cartIcon(active: false),
                activeIcon: _cartIcon(active: true),
                label: 'Cart',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.person_outline_rounded),
                activeIcon: Icon(Icons.person_rounded),
                label: 'Profile',
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════ PRIVATE WIDGETS ═══════════════════════════

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
    this.showDot = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.inputFill,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(icon, size: 21, color: AppColors.textPrimary),
          ),
          if (showDot)
            Positioned(
              top: 9,
              right: 10,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.onAction,
    this.actionLabel,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 14),
      child: Row(
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              behavior: HitTestBehavior.opaque,
              child: Text(
                actionLabel!,
                style: AppTextStyles.link.copyWith(fontSize: 12.5),
              ),
            ),
        ],
      ),
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({
    required this.data,
    required this.seed,
    required this.onShopNow,
  });

  final _BannerData data;
  final int seed;
  final VoidCallback onShopNow;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Banner picture placeholder (replace with the promo image).
          ProductImage(seed: seed, iconSize: 48),
          // Coral fade so the text stays readable.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  AppColors.primary,
                  AppColors.primary,
                  AppColors.primary.withAlpha(0),
                ],
                stops: const [0.0, 0.5, 0.82],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 190),
                  child: Text(
                    data.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: onShopNow,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
                      child: Text(
                        'Shop now',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}