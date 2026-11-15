import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/ps_colors.dart';
import '../../core/theme/ps_tokens.dart';
import '../../services/wishlist_service.dart';
import '../shared/ps_buttons.dart';
import '../shared/ps_motion.dart';
import '../shared/ps_toast.dart';

/// COM-C07 My Picks toggle. Reads/writes [WishlistStore] so every heart for
/// the same product updates together; failures roll back with a toast.
class PsWishlistButton extends StatelessWidget {
  const PsWishlistButton({
    super.key,
    required this.productId,
    this.filled = true,
    this.size = 20,
    this.compact = false,
  });

  final int productId;

  /// White circular chip (over images) vs. bare icon.
  final bool filled;
  final double size;

  /// Product cards: a small 30pt chip inside the full 44pt tap area, so the
  /// heart doesn't cover the photo.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final store = WishlistStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final saved = store.contains(productId);
        Future<void> toggle() async {
          try {
            final nowSaved = await store.toggle(productId);
            if (context.mounted) PsToast.show(context, nowSaved ? 'Saved to My Picks' : 'Removed from My Picks');
          } on ApiException catch (e) {
            if (context.mounted) PsToast.error(context, e.statusCode == 401 ? 'Log in to save items.' : e.message);
          }
        }

        if (compact) {
          return Semantics(
            button: true,
            label: saved ? 'Remove from My Picks' : 'Save to My Picks',
            excludeSemantics: true,
            child: PsPressable(
              scale: 0.85,
              child: InkResponse(
                onTap: toggle,
                radius: 20,
                child: SizedBox.square(
                  dimension: PsSize.minTap,
                  child: Center(
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(color: PsColors.surface.withAlpha(225), shape: BoxShape.circle),
                      child: PsIconSwap(
                        icon: Icon(
                          saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          size: size,
                          color: saved ? PsColors.primary : PsColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        return PsIconButton(
          icon: saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: saved ? PsColors.primary : PsColors.textPrimary,
          size: size,
          filled: filled,
          tooltip: saved ? 'Remove from My Picks' : 'Save to My Picks',
          onPressed: toggle,
        );
      },
    );
  }
}
