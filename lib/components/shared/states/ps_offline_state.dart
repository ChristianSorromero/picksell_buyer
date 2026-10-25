import 'package:flutter/material.dart';

import '../../../core/theme/ps_colors.dart';
import '../../../core/theme/ps_tokens.dart';
import '../../../core/theme/ps_typography.dart';
import '../ps_buttons.dart';
import 'ps_state_layout.dart';

/// SYS-C15 Offline State (banner) — slim notice under the top bar while
/// cached content stays visible. Network-only actions should be disabled
/// by the screen while this shows.
class PsOfflineBanner extends StatelessWidget {
  const PsOfflineBanner({super.key, this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        color: PsColors.textPrimary,
        padding: const EdgeInsets.symmetric(horizontal: PsSpace.gutter, vertical: 6),
        child: Row(
          children: [
            const Icon(Icons.wifi_off_rounded, size: 16, color: Colors.white),
            const SizedBox(width: PsSpace.xs),
            Expanded(
              child: Text(
                'You’re offline. Showing saved information.',
                style: PsText.caption.copyWith(color: Colors.white),
              ),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  foregroundColor: PsColors.primary,
                  minimumSize: const Size(PsSize.minTap, 32),
                  textStyle: PsText.caption.copyWith(fontWeight: FontWeight.w700),
                ),
                child: const Text('Retry'),
              ),
          ],
        ),
      ),
    );
  }
}

/// SYS-C15 Offline State (full screen) — when nothing cached is available.
class PsOfflineState extends StatelessWidget {
  const PsOfflineState({super.key, this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return PsCenteredScrollable(
      child: PsStateLayout(
        icon: Icons.wifi_off_rounded,
        iconColor: PsColors.textMuted,
        haloColor: PsColors.neutralSoft,
        title: 'No internet connection',
        message: 'Check your Wi-Fi or mobile data, then try again.',
        action: onRetry == null
            ? null
            : PsSecondaryButton.outlined(
                label: 'Try again',
                icon: Icons.refresh_rounded,
                onPressed: onRetry,
              ),
      ),
    );
  }
}
