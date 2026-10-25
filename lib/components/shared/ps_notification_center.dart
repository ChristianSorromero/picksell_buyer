import 'package:flutter/material.dart';

import '../../core/theme/ps_colors.dart';
import '../../core/theme/ps_tokens.dart';
import '../../core/theme/ps_typography.dart';
import 'ps_refreshable.dart';
import 'states/ps_empty_state.dart';
import 'states/ps_error_state.dart';
import 'states/ps_loading_state.dart';

/// Display data for one notification row. Screens map their domain model
/// (order, message, promo, account event) into this.
class PsNotificationEntry {
  const PsNotificationEntry({
    required this.id,
    required this.icon,
    required this.title,
    required this.body,
    required this.timeLabel,
    this.iconColor = PsColors.primary,
    this.unread = false,
    this.onTap,
  });

  final String id;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;
  final String timeLabel;
  final bool unread;
  final VoidCallback? onTap;
}

/// SYS-C16 Notification Center — one list for order, logistics, message
/// and account notifications, with loading/empty/error states and
/// pull-to-refresh built in.
class PsNotificationCenter extends StatelessWidget {
  const PsNotificationCenter({
    super.key,
    required this.entries,
    required this.onRefresh,
    this.loading = false,
    this.errorMessage,
  });

  final List<PsNotificationEntry> entries;
  final Future<void> Function() onRefresh;
  final bool loading;

  /// Non-null shows [PsErrorState] with retry.
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    if (loading && entries.isEmpty) return const PsSkeletonList(itemCount: 6, thumbnail: false);

    final Widget content;
    if (errorMessage != null && entries.isEmpty) {
      content = PsErrorState(
        title: 'Couldn’t load notifications',
        message: errorMessage!,
        onRetry: onRefresh,
      );
    } else if (entries.isEmpty) {
      content = const PsEmptyState(
        icon: Icons.notifications_none_rounded,
        title: 'You’re all caught up',
        message: 'Order updates, messages and account alerts will appear here.',
      );
    } else {
      content = ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: PsSpace.xs),
        itemCount: entries.length,
        separatorBuilder: (_, __) => const Divider(indent: 72),
        itemBuilder: (_, i) => PsNotificationTile(entry: entries[i]),
      );
    }
    return PsRefreshable(onRefresh: onRefresh, child: content);
  }
}

class PsNotificationTile extends StatelessWidget {
  const PsNotificationTile({super.key, required this.entry});

  final PsNotificationEntry entry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${entry.unread ? 'Unread. ' : ''}${entry.title}. ${entry.body}. ${entry.timeLabel}',
      button: entry.onTap != null,
      excludeSemantics: true,
      child: InkWell(
        onTap: entry.onTap,
        child: Container(
          color: entry.unread ? PsColors.primarySoft.withAlpha(110) : null,
          padding: const EdgeInsets.symmetric(horizontal: PsSpace.gutter, vertical: PsSpace.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: entry.iconColor.withAlpha(30), shape: BoxShape.circle),
                child: Icon(entry.icon, color: entry.iconColor, size: 22),
              ),
              const SizedBox(width: PsSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(entry.title, style: PsText.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: PsSpace.xs),
                        Text(entry.timeLabel, style: PsText.caption.copyWith(fontSize: 11.5)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(entry.body, style: PsText.bodyMuted, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (entry.unread)
                Padding(
                  padding: const EdgeInsets.only(left: PsSpace.xs, top: 6),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(color: PsColors.primary, shape: BoxShape.circle),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
