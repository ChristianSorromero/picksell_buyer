import 'dart:async';

import 'package:flutter/material.dart';

import '../../../components/components.dart';
import '../../../format_utils.dart';
import '../../../models/cart.dart';
import '../../../models/catalog.dart';
import '../../../services/cart_service.dart';
import '../../../services/catalog_service.dart';
import '../../../services/checkout_service.dart';
import '../nav.dart';

/// Cart (COM-C12/C13/C14): seller groups, selection, quantity edits,
/// variation changes, bulk delete, voucher choice and checkout.
class CartTab extends StatefulWidget {
  const CartTab({super.key});

  @override
  State<CartTab> createState() => _CartTabState();
}

class _CartTabState extends State<CartTab> {
  final _store = CartStore.instance;
  final _checkout = CheckoutService();

  bool _loading = true;
  Object? _error;
  bool _editing = false;
  final Set<int> _selected = {};
  final Set<int> _known = {};
  final Set<int> _busy = {};

  /// Checkout selection parked while Edit mode uses selection for removal.
  Set<int> _checkoutSelection = {};

  String? _voucherCode;
  CartQuote? _selectionQuote;
  int _quoteRequest = 0;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStore);
    ShellNav.tab.addListener(_onTab);
    _reload();
  }

  @override
  void dispose() {
    _store.removeListener(_onStore);
    ShellNav.tab.removeListener(_onTab);
    super.dispose();
  }

  void _onTab() {
    if (ShellNav.tab.value == BuyerTab.cart) _reload();
  }

  /// New lines (added elsewhere) start selected; vanished lines drop out.
  void _onStore() {
    if (!mounted) return;
    final lines = _store.quote.lines;
    final ids = lines.map((l) => l.id).toSet();
    setState(() {
      _selected.retainAll(ids);
      for (final l in lines) {
        if (_known.add(l.id) && l.purchasable) _selected.add(l.id);
      }
      _known.retainAll(ids);
    });
  }

  Future<void> _reload() async {
    setState(() {
      _loading = _store.quote.isEmpty;
      _error = null;
    });
    try {
      await _store.load();
      _requote();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<CartLine> get _lines => _store.quote.lines;
  List<int> get _checkoutIds => [for (final l in _lines) if (_selected.contains(l.id) && l.purchasable) l.id];

  /// Server price for the current selection + voucher.
  Future<void> _requote() async {
    final ids = _checkoutIds;
    final id = ++_quoteRequest;
    if (ids.isEmpty || _voucherCode == null) {
      setState(() => _selectionQuote = null);
      return;
    }
    try {
      final q = await _checkout.quote(lineIds: ids, voucherCode: _voucherCode);
      if (!mounted || id != _quoteRequest) return;
      setState(() => _selectionQuote = q);
      if (q.voucherError != null) {
        PsToast.error(context, q.voucherError!);
        setState(() => _voucherCode = null);
      }
    } catch (_) {
      if (mounted && id == _quoteRequest) setState(() => _selectionQuote = null);
    }
  }

  double get _selectedSubtotal => _lines.where((l) => _checkoutIds.contains(l.id)).fold(0.0, (s, l) => s + l.lineTotal);
  double get _discount => _selectionQuote?.voucher?.discount ?? 0;

  void _toggle(int id, bool v) {
    setState(() => v ? _selected.add(id) : _selected.remove(id));
    _requote();
  }

  void _toggleAll(Iterable<CartLine> lines, bool v) {
    setState(() {
      for (final l in lines) {
        if (_editing || l.purchasable) v ? _selected.add(l.id) : _selected.remove(l.id);
      }
    });
    _requote();
  }

  Future<void> _setQuantity(CartLine line, int qty) async {
    setState(() => _busy.add(line.id));
    try {
      await _store.setQuantity(line, qty);
      _requote();
    } catch (e) {
      if (mounted) PsToast.error(context, errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy.remove(line.id));
    }
  }

  Future<void> _editVariation(CartLine line) async {
    ProductDetail detail;
    try {
      detail = await CatalogService().product(line.product.id);
    } catch (e) {
      if (mounted) PsToast.error(context, errorMessage(e));
      return;
    }
    if (!mounted) return;
    await PsProductConfigSheet.show(
      context,
      detail: detail,
      actionLabel: 'Update',
      initialVariationIds: line.variationIds,
      initialQuantity: line.quantity,
      onSubmit: (s) async {
        await _store.setVariations(line, s.variationIds);
        final updated = _store.quote.lines.where((l) => l.id == line.id).firstOrNull;
        if (updated != null && updated.quantity != s.quantity) await _store.setQuantity(updated, s.quantity);
      },
    );
    _requote();
  }

  /// Edit mode starts with nothing ticked so a stray tap can't delete the
  /// whole cart; leaving it restores the checkout selection.
  void _toggleEditing() {
    setState(() {
      _editing = !_editing;
      if (_editing) {
        _checkoutSelection = {..._selected};
        _selected.clear();
      } else {
        final ids = _lines.where((l) => l.purchasable).map((l) => l.id).toSet();
        _selected
          ..clear()
          ..addAll(_checkoutSelection.intersection(ids));
      }
    });
    if (!_editing) _requote();
  }

  Future<void> _deleteSelected() async {
    final ids = _selected.toList();
    if (ids.isEmpty) return;
    final ok = await PsDialog.confirm(
      context,
      title: 'Remove ${ids.length} ${ids.length == 1 ? 'item' : 'items'}?',
      message: 'They’ll be removed from your cart. You can add them again anytime.',
      confirmLabel: 'Remove',
      cancelLabel: 'Keep',
      destructive: true,
    );
    if (!ok) return;
    try {
      await _store.removeMany(ids);
      if (!mounted) return;
      _checkoutSelection.removeAll(ids);
      _toggleEditing();
      PsToast.success(context, 'Removed from cart');
    } catch (e) {
      if (mounted) PsDialog.error(context, title: 'Couldn’t remove items', message: errorMessage(e));
    }
  }

  Future<void> _pickVoucher() async {
    final ids = _checkoutIds;
    if (ids.isEmpty) {
      PsToast.show(context, 'Select items first to see vouchers that apply.');
      return;
    }
    final code = await PsBottomSheet.show<String>(
      context,
      title: 'Select Voucher',
      builder: (_) => PsVoucherSheet(
        selectedCode: _voucherCode,
        load: () async {
          final d = await _checkout.vouchersFor(ids);
          return (platform: d.platform, store: d.store);
        },
      ),
    );
    if (code == null) return;
    setState(() => _voucherCode = code.isEmpty ? null : code);
    await _requote();
    if (mounted && _selectionQuote?.voucher != null) PsToast.success(context, '${_selectionQuote!.voucher!.title} applied');
  }

  Future<void> _checkoutNow() async {
    final ids = _checkoutIds;
    if (ids.isEmpty) return;
    await openCheckout(context, ids, voucherCode: _voucherCode);
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        final quote = _store.quote;
        return PsAppShell(
          topBar: PsTopBar(
            title: 'Cart${quote.itemCount > 0 ? ' (${quote.itemCount})' : ''}',
            showBack: false,
            actions: [
              if (!quote.isEmpty)
                TextButton(
                  onPressed: _toggleEditing,
                  child: Text(_editing ? 'Done' : 'Edit', style: PsText.link.copyWith(color: PsColors.textMuted)),
                ),
            ],
          ),
          footer: quote.isEmpty ? null : _footer(quote),
          body: _body(quote),
        );
      },
    );
  }

  Widget _body(CartQuote quote) {
    if (_loading && quote.isEmpty) return const PsSkeletonList(itemCount: 3);
    final e = _error;
    if (e != null && quote.isEmpty) {
      return e is ApiException && e.isNetworkError ? PsOfflineState(onRetry: _reload) : PsErrorState(message: errorMessage(e), onRetry: _reload);
    }
    if (quote.isEmpty) {
      return PsRefreshable(
        onRefresh: _reload,
        child: PsEmptyState(
          icon: Icons.shopping_cart_outlined,
          title: 'Your cart is empty',
          message: 'Browse products and add your picks here.',
          actionLabel: 'Start shopping',
          onAction: () => ShellNav.tab.value = BuyerTab.home,
        ),
      );
    }

    return PsRefreshable(
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(PsSpace.gutter, PsSpace.xs, PsSpace.gutter, PsSpace.lg),
        children: [
          if (quote.hasIssues)
            Padding(
              padding: const EdgeInsets.only(bottom: PsSpace.sm),
              child: PsCard(
                color: PsColors.warningSoft,
                borderColor: PsColors.warning.withAlpha(80),
                child: Text('Some items changed since you added them. Adjust or remove them to check out.',
                    style: PsText.caption.copyWith(color: PsColors.warning, fontWeight: FontWeight.w600)),
              ),
            ),
          for (final group in quote.groups) ...[
            PsSellerGroupHeader(
              name: group.seller?.name ?? 'Seller',
              verified: group.seller?.verified ?? false,
              allSelected: group.items.every((l) => _selected.contains(l.id)),
              someSelected: group.items.any((l) => _selected.contains(l.id)),
              onSelected: (v) => _toggleAll(group.items, v),
              onTap: group.seller == null ? null : () => openStore(context, group.seller!.id),
            ),
            for (final line in group.items) ...[
              PsCartItemTile(
                line: line,
                editing: _editing,
                selected: _selected.contains(line.id),
                busy: _busy.contains(line.id),
                onSelected: (v) => _toggle(line.id, v),
                onQuantity: (q) => _setQuantity(line, q),
                onTap: () => openProduct(context, line.product.id),
                onEditVariation: line.variationIds.isEmpty ? null : () => _editVariation(line),
              ),
              const SizedBox(height: PsSpace.xs),
            ],
            PsSellerGroupFooter(shippingFee: group.shippingFee, shippingName: quote.shippingOption?.name),
            const SizedBox(height: PsSpace.md),
          ],
          PsCard(
            onTap: _pickVoucher,
            child: Row(
              children: [
                const Icon(Icons.confirmation_number_outlined, color: PsColors.primaryStrong),
                const SizedBox(width: PsSpace.sm),
                Expanded(child: Text('Picksell Voucher', style: PsText.bodyStrong)),
                if (_selectionQuote?.voucher != null)
                  PsTag('-${formatPeso(_selectionQuote!.voucher!.discount)}')
                else
                  Text('Select or enter code', style: PsText.caption),
                const Icon(Icons.chevron_right_rounded, color: PsColors.textMuted),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer(CartQuote quote) {
    final selectableLines = _editing ? quote.lines : quote.lines.where((l) => l.purchasable).toList();
    final allSelected = selectableLines.isNotEmpty && selectableLines.every((l) => _selected.contains(l.id));
    final count = _lines.where((l) => _checkoutIds.contains(l.id)).fold<int>(0, (s, l) => s + l.quantity);
    final total = _selectedSubtotal - _discount;

    return DecoratedBox(
      decoration: const BoxDecoration(color: PsColors.surface, border: Border(top: BorderSide(color: PsColors.border))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, PsSpace.xs, PsSpace.gutter, PsSpace.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  PsCheck(value: allSelected, label: 'Select all', onChanged: (v) => _toggleAll(selectableLines, v)),
                  Text('Select All', style: PsText.bodyMuted),
                  const Spacer(),
                  if (!_editing)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Total Price', style: PsText.caption),
                        Text(formatPesoFixed(total < 0 ? 0 : total), style: PsText.price.copyWith(fontSize: 20)),
                        if (_discount > 0) Text('Saved ${formatPesoFixed(_discount)}', style: PsText.caption.copyWith(color: PsColors.primaryStrong)),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: PsSpace.xs),
              Padding(
                padding: const EdgeInsets.only(left: PsSpace.sm),
                child: _editing
                    ? OutlinedButton(
                        onPressed: _selected.isEmpty ? null : _deleteSelected,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: PsColors.error,
                          side: const BorderSide(color: PsColors.error),
                          minimumSize: const Size.fromHeight(PsSize.buttonHeight),
                          shape: RoundedRectangleBorder(borderRadius: PsRadius.button),
                        ),
                        child: Text('Delete (${_selected.length})'),
                      )
                    : PsPrimaryButton(
                        label: count > 0 ? 'Check Out ($count)' : 'Check Out',
                        uppercase: false,
                        onPressed: count > 0 ? _checkoutNow : null,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
