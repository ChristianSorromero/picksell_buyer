import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/ps_colors.dart';
import '../../services/wishlist_service.dart';
import '../shared/ps_buttons.dart';
import '../shared/ps_toast.dart';

/// COM-C07 My Picks toggle. Reads/writes [WishlistStore] so every heart for
/// the same product updates together; failures roll back with a toast.
class PsWishlistButton extends StatelessWidget {
  const PsWishlistButton({super.key, required this.productId, this.filled = true, this.size = 20});

  final int productId;

  /// White circular chip (over images) vs. bare icon.
  final bool filled;
  final double size;

  @override
  Widget build(BuildContext context) {
    final store = WishlistStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final saved = store.contains(productId);
        return PsIconButton(
          icon: saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: saved ? PsColors.primary : PsColors.textPrimary,
          size: size,
          filled: filled,
          tooltip: saved ? 'Remove from My Picks' : 'Save to My Picks',
          onPressed: () async {
            try {
              final nowSaved = await store.toggle(productId);
              if (context.mounted) PsToast.show(context, nowSaved ? 'Saved to My Picks' : 'Removed from My Picks');
            } on ApiException catch (e) {
              if (context.mounted) PsToast.error(context, e.statusCode == 401 ? 'Log in to save items.' : e.message);
            }
          },
        );
      },
    );
  }
}
