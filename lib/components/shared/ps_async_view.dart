import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import 'ps_refreshable.dart';
import 'states/ps_error_state.dart';
import 'states/ps_loading_state.dart';
import 'states/ps_offline_state.dart';

/// Runs [load] and renders the §12 state for it: skeleton while loading,
/// offline/error states with retry, [empty] when [isEmpty] says so, and
/// [builder] with pull-to-refresh otherwise.
///
/// Reload from outside with a `GlobalKey<PsAsyncViewState<T>>`.
class PsAsyncView<T> extends StatefulWidget {
  const PsAsyncView({
    super.key,
    required this.load,
    required this.builder,
    this.loading,
    this.isEmpty,
    this.empty,
    this.errorTitle = 'Couldn’t load this page',
    this.refreshable = true,
  });

  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, Future<void> Function() reload) builder;

  /// Skeleton matching the final layout; defaults to [PsSkeletonList].
  final Widget? loading;
  final bool Function(T data)? isEmpty;
  final Widget? empty;
  final String errorTitle;

  /// Wraps content in [PsRefreshable]; content must be scrollable.
  final bool refreshable;

  @override
  State<PsAsyncView<T>> createState() => PsAsyncViewState<T>();
}

class PsAsyncViewState<T> extends State<PsAsyncView<T>> {
  T? _data;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  T? get data => _data;

  Future<void> reload() async {
    if (_data == null) setState(() => _loading = true);
    try {
      final data = await widget.load();
      if (!mounted) return;
      setState(() {
        _data = data;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  /// Replace the data locally after a mutation that returned fresh state.
  void replace(T data) => setState(() => _data = data);

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (_loading && data == null) return widget.loading ?? const PsSkeletonList();

    if (data == null) {
      final e = _error;
      if (e is ApiException && e.isNetworkError) return PsOfflineState(onRetry: reload);
      return PsErrorState(
        title: widget.errorTitle,
        message: e is ApiException ? e.message : 'Please try again in a moment.',
        onRetry: reload,
      );
    }

    if (widget.isEmpty?.call(data) ?? false) {
      final empty = widget.empty ?? const SizedBox.shrink();
      return widget.refreshable ? PsRefreshable(onRefresh: reload, child: empty) : empty;
    }

    final content = widget.builder(context, data, reload);
    return widget.refreshable ? PsRefreshable(onRefresh: reload, child: content) : content;
  }
}

/// Maps any thrown error to a user-facing sentence.
String errorMessage(Object e) => e is ApiException ? e.message : 'Something went wrong. Please try again.';
