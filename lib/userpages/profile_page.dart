import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app_colors.dart';
import '../page_transitions.dart';
import 'login.dart';
import '../app_text_styles.dart';
import '../services/auth_service.dart';

/// Profile tab. Embedded directly in the buyer dashboard's bottom nav
/// (no Scaffold/AppBar of its own), same pattern as CartPage.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final SessionManager _session = SessionManager();

  String _name = '';
  String _email = '';
  bool _loading = true;

  // TODO: replace with real counts once an orders/wishlist/reviews
  // endpoint exists on the backend. Hardcoded to match the design for now.
  final int _orders = 12;
  final int _wishlist = 48;
  final int _reviews = 24;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final name = await _session.getName();
    final email = await _session.getEmail();
    if (!mounted) return;
    setState(() {
      _name = (name == null || name.isEmpty) ? 'Guest' : name;
      _email = email ?? '';
      _loading = false;
    });
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Log out',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _session.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(fadeRoute(const LoginPage()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        children: [
          Center(child: _buildAvatar()),
          const SizedBox(height: 14),
          Center(
            child: Text(
              _name,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Center(child: Text(_email, style: AppTextStyles.small)),
          const SizedBox(height: 16),
          Center(child: _buildEditProfileButton()),
          const SizedBox(height: 22),
          _buildStatsCard(),
          const SizedBox(height: 22),
          _buildMenuCard(const [
            _MenuItemData(Icons.receipt_long_rounded, 'My Orders'),
            _MenuItemData(Icons.location_on_outlined, 'Addresses'),
            _MenuItemData(Icons.credit_card_rounded, 'Payment Methods'),
            _MenuItemData(Icons.favorite_border_rounded, 'Wishlist'),
            _MenuItemData(Icons.settings_outlined, 'Settings'),
            _MenuItemData(Icons.help_outline_rounded, 'Help Center'),
          ]),
          const SizedBox(height: 14),
          _buildMenuCard([
            _MenuItemData(
              Icons.logout_rounded,
              'Logout',
              destructive: true,
              onTap: _logout,
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.inputFill,
            border: Border.all(color: AppColors.border),
          ),
          child: const Icon(
            Icons.person_rounded,
            size: 46,
            color: AppColors.textHint,
          ),
        ),
        Positioned(
          right: -2,
          bottom: -2,
          child: GestureDetector(
            onTap: () => _showSnack('Photo upload coming soon'),
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEditProfileButton() {
    return OutlinedButton(
      onPressed: () => _showSnack('Edit profile coming soon'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: Text(
        'Edit Profile',
        style: AppTextStyles.socialButton.copyWith(color: AppColors.primary),
      ),
    );
  }

  Widget _buildStatsCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(child: _StatItem(value: _orders, label: 'Orders')),
          _statDivider(),
          Expanded(child: _StatItem(value: _wishlist, label: 'Wishlist')),
          _statDivider(),
          Expanded(child: _StatItem(value: _reviews, label: 'Reviews')),
        ],
      ),
    );
  }

  Widget _statDivider() =>
      Container(width: 1, height: 32, color: AppColors.border);

  Widget _buildMenuCard(List<_MenuItemData> items) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _MenuRow(
              data: items[i],
              onTap: items[i].onTap ??
                  () => _showSnack('${items[i].label} coming soon'),
            ),
            if (i != items.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Divider(height: 1, color: AppColors.border),
              ),
          ],
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value',
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 3),
        Text(label, style: AppTextStyles.small.copyWith(fontSize: 11)),
      ],
    );
  }
}

class _MenuItemData {
  const _MenuItemData(
    this.icon,
    this.label, {
    this.destructive = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool destructive;
  final VoidCallback? onTap;
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.data, required this.onTap});

  final _MenuItemData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = data.destructive ? AppColors.primary : AppColors.textPrimary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(data.icon, size: 20, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                data.label,
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: color,
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
    );
  }
}
