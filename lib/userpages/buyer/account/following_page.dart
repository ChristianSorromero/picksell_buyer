import 'package:flutter/material.dart';

import '../../../components/components.dart';
import '../../../services/follow_service.dart';
import '../shop/store_page.dart';

/// Following (website: Following page): the stores the buyer follows, newest
/// first, to visit or unfollow.
class FollowingPage extends StatefulWidget {
  const FollowingPage({super.key});

  @override
  State<FollowingPage> createState() => _FollowingPageState();
}

class _FollowingPageState extends State<FollowingPage> {
  final _service = FollowService();
  final List<FollowedStore> _stores = [];
  int _page = 0;
  bool _hasMore = true;
  bool _loading = false;
  Object? _error;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _stores.clear();
      _page = 0;
      _hasMore = true;
      _error = null;
    });
    await _more();
  }

  Future<void> _more() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    try {
      final r = await _service.following(page: _page + 1);
      if (!mounted) return;
      setState(() {
        _stores.addAll(r.stores);
        _page = r.meta.currentPage;
        _hasMore = r.meta.hasMore;
        _total = r.meta.total;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _unfollow(FollowedStore s) async {
    final ok = await PsDialog.confirm(
      context,
      title: 'Unfollow ${s.name}?',
      message: 'You can follow it again from its store page.',
      confirmLabel: 'Unfollow',
      icon: Icons.storefront_outlined,
    );
    if (!ok) return;
    try {
      await _service.set(s.id, follow: false);
      if (!mounted) return;
      setState(() {
        _stores.removeWhere((x) => x.id == s.id);
        _total = (_total - 1).clamp(0, 1 << 30);
      });
      PsToast.show(context, 'You unfollowed ${s.name}.');
    } on ApiException catch (e) {
      if (mounted) PsToast.error(context, e.message);
    }
  }

  Future<void> _visit(FollowedStore s) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => StorePage(sellerId: s.id)));
    // They may have unfollowed from the store page.
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return PsAppShell(
      topBar: PsTopBar(title: _total > 0 ? 'Following ($_total)' : 'Following'),
      body: _body(),
    );
  }

  Widget _body() {
    if (_stores.isEmpty) {
      if (_loading) return const PsSkeletonList(itemCount: 4, thumbnail: true);
      final e = _error;
      if (e != null) {
        return e is ApiException && e.isNetworkError
            ? PsOfflineState(onRetry: _refresh)
            : PsErrorState(title: 'Couldn’t load the stores you follow', message: errorMessage(e), onRetry: _refresh);
      }
      return const PsEmptyState(
        icon: Icons.storefront_outlined,
        title: 'Not following any stores yet',
        message: 'Tap Follow on a store page to keep your favourite shops here.',
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.extentAfter < 300) _more();
          return false;
        },
        child: ListView.separated(
          padding: const EdgeInsets.all(PsSpace.gutter),
          itemCount: _stores.length + (_hasMore ? 1 : 0),
          separatorBuilder: (_, __) => const SizedBox(height: PsSpace.sm),
          itemBuilder: (context, i) {
            if (i == _stores.length) {
              return const Padding(padding: EdgeInsets.all(PsSpace.md), child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
            }
            final s = _stores[i];
            return PsCard(
              onTap: () => _visit(s),
              child: Row(
                children: [
                  PsSellerAvatar(name: s.name, logo: s.logo, size: 52),
                  const SizedBox(width: PsSpace.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(child: Text(s.name, style: PsText.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis)),
                            if (s.verified) ...[const SizedBox(width: 4), const PsVerifiedBadge()],
                          ],
                        ),
                        Text(
                          [
                            if (s.location.isNotEmpty) s.location,
                            '${s.activeProducts} ${s.activeProducts == 1 ? 'product' : 'products'}',
                          ].join(' · '),
                          style: PsText.caption,
                        ),
                        if (s.onVacation) ...[const SizedBox(height: 4), const PsTag.muted('ON VACATION')],
                      ],
                    ),
                  ),
                  PsSecondaryButton(label: 'Unfollow', onPressed: () => _unfollow(s)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
