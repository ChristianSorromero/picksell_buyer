import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../components/components.dart';
import '../../../services/catalog_service.dart';
import 'product_list_page.dart';

/// SYS-C17 Search — typeahead suggestions from the catalog plus recent
/// searches kept on-device. Submitting opens the filtered product list.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  static const _historyKey = 'search_history';

  final _catalog = CatalogService();
  final _query = TextEditingController();
  List<String> _history = [];
  ({List<String> products, List<String> categories}) _suggestions = (products: [], categories: []);
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted) setState(() => _history = p.getStringList(_historyKey) ?? []);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _suggest(String q) async {
    final id = ++_requestId;
    if (q.length < 2) {
      setState(() => _suggestions = (products: [], categories: []));
      return;
    }
    try {
      final s = await _catalog.suggestions(q);
      if (mounted && id == _requestId) setState(() => _suggestions = s);
    } catch (_) {
      // Suggestions are optional; submitting still works offline-tolerant.
    }
  }

  Future<void> _remember(String term) async {
    if (term.isEmpty) return;
    final next = [term, ..._history.where((h) => h.toLowerCase() != term.toLowerCase())].take(8).toList();
    _history = next;
    try {
      (await SharedPreferences.getInstance()).setStringList(_historyKey, next);
    } catch (_) {}
  }

  /// Replaces this screen with the matching product list.
  void _open(String term, {String? category}) {
    if (category == null) _remember(term);
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => ProductListPage(
        title: category ?? '“$term”',
        initialSearch: category == null ? term : null,
        initialCategory: category,
      ),
    ));
  }

  Future<void> _clearHistory() async {
    setState(() => _history = []);
    try {
      (await SharedPreferences.getInstance()).remove(_historyKey);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final typing = _query.text.trim().length >= 2;
    return PsAppShell(
      topBar: PsTopBar(
        titleWidget: Padding(
          padding: const EdgeInsets.only(right: PsSpace.sm),
          child: PsSearchBar(
            controller: _query,
            autofocus: true,
            hint: 'Search products or categories',
            debounce: const Duration(milliseconds: 250),
            onChanged: _suggest,
            onSubmitted: (q) {
              if (q.trim().isNotEmpty) _open(q.trim());
            },
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: PsSpace.sm),
        children: [
          if (typing) ...[
            for (final c in _suggestions.categories)
              ListTile(
                leading: const Icon(Icons.category_outlined),
                title: Text(c, style: PsText.bodyStrong),
                subtitle: Text('Category', style: PsText.caption),
                onTap: () => _open(c, category: c),
              ),
            for (final p in _suggestions.products)
              ListTile(
                leading: const Icon(Icons.search_rounded),
                title: Text(p, style: PsText.body),
                onTap: () => _open(p),
              ),
            ListTile(
              leading: const Icon(Icons.arrow_forward_rounded, color: PsColors.primaryStrong),
              title: Text('Search for “${_query.text.trim()}”', style: PsText.link),
              onTap: () => _open(_query.text.trim()),
            ),
          ] else if (_history.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(PsSpace.gutter, PsSpace.xs, PsSpace.xs, 0),
              child: Row(
                children: [
                  Expanded(child: Text('RECENT SEARCHES', style: PsText.overline)),
                  TextButton(onPressed: _clearHistory, child: const Text('Clear')),
                ],
              ),
            ),
            Padding(
              padding: PsSpace.page,
              child: Wrap(
                spacing: PsSpace.xs,
                runSpacing: PsSpace.xs,
                children: [for (final h in _history) ActionChip(label: Text(h), onPressed: () => _open(h))],
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.all(PsSpace.xl),
              child: Text('Search by product name or category.', style: PsText.bodyMuted, textAlign: TextAlign.center),
            ),
        ],
      ),
    );
  }
}
