import 'dart:math';
import 'package:flutter/material.dart';

import '../../../components/components.dart';
import '../../../format_utils.dart';
import '../../../models/address.dart';
import '../../../models/cart.dart';
import '../../../models/checkout_vouchers.dart';
import '../../../services/cart_service.dart';
import '../../../services/checkout_service.dart';
import '../account/address_book_page.dart';
import '../account/edit_profile_page.dart';
import 'order_placed_page.dart';
import 'voucher_picker_sheet.dart';

/// Order Summary / Checkout (COM-C14…C19) with the website's checkout rules:
/// delivered to the buyer's default address or one from their address book,
/// Cash on Delivery, priced by the product discount and the product's own
/// voucher code, plus the delivery fee to the chosen address, less the store
/// and PickSell vouchers picked (website: checkout voucher picker).
class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key, required this.lineIds, this.voucherCode});

  final List<int> lineIds;
  final String? voucherCode;

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _checkout = CheckoutService();

  CartQuote? _quote;
  CheckoutShipTo? _address;

  /// The address-book entry chosen for this checkout; null ships to the default address.
  int? _addressId;
  late String? _voucher = widget.voucherCode;

  /// Store and PickSell vouchers picked; the quote keeps only the ones that apply.
  VoucherPicks _picks = const VoucherPicks();

  /// Logistics company per seller id ("Ship with"); empty = the recommended ones.
  final Map<int, int> _carriers = {};
  CheckoutVouchers _vouchers = const CheckoutVouchers();
  double _payable = 0;
  Object? _error;
  bool _quoting = true;
  bool _placing = false;

  @override
  void initState() {
    super.initState();
    _requote();
  }

  Future<void> _requote({String? code}) async {
    setState(() => _quoting = true);
    try {
      final r = await _checkout.quote(lineIds: widget.lineIds, voucherCode: _voucher, addressId: _addressId, vouchers: _picks, code: code, carriers: _carriers);
      if (!mounted) return;
      setState(() {
        _quote = r.quote;
        _address = r.shipTo;
        _vouchers = r.vouchers;
        _payable = r.payable;
        // The server drops picks that no longer apply (spend changed, used up...).
        _picks = VoucherPicks(stores: r.vouchers.pickedStores, platform: r.vouchers.pickedPlatform);
        // Keep the server's choice per parcel so the order goes with what was shown.
        for (final g in r.quote.groups) {
          final sellerId = g.seller?.id;
          if (sellerId != null && g.carrierId != null) _carriers[sellerId] = g.carrierId!;
        }
        _error = null;
        if (r.quote.voucherError != null) _voucher = null;
      });
      if (r.quote.voucherError != null) PsToast.error(context, r.quote.voucherError!);
      if (r.vouchers.error != null) PsToast.error(context, r.vouchers.error!);
    } on ApiException catch (e) {
      // The chosen address was removed (here or on the website): back to the default.
      if (_addressId != null && e.fieldError('address_id') != null) {
        _addressId = null;
        if (mounted) PsToast.error(context, 'That address is no longer saved. Shipping to your default address.');
        return _requote();
      }
      if (mounted) setState(() => _error = e);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _quoting = false);
    }
  }

  /// Choose another address (or add one) for this order.
  Future<void> _changeAddress() async {
    final choice = await Navigator.of(context).push<AddressChoice>(
      MaterialPageRoute(builder: (_) => AddressBookPage(picking: true, selectedId: _addressId)),
    );
    if (!mounted) return;
    if (choice != null) _addressId = choice.id;
    _requote();
  }

  /// Fix the address this order ships to: the default lives in the profile,
  /// a saved one in the address book.
  Future<void> _editAddress() async {
    if (_addressId == null) {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EditProfilePage(focusAddress: true)));
    } else {
      await _changeAddress();
      return;
    }
    if (mounted) _requote();
  }

  /// Voucher sheets: the page gutter on both sides and room above the home bar.
  static const _sheetPadding = EdgeInsets.fromLTRB(PsSpace.gutter, PsSpace.xs, PsSpace.gutter, PsSpace.md);

  Future<void> _enterVoucher() async {
    final code = await PsBottomSheet.show<String>(
      context,
      title: 'Product voucher',
      builder: (_) => VoucherCodeSheet(initial: _voucher),
    );
    if (code == null) return;
    setState(() => _voucher = code.isEmpty ? null : code);
    _requote();
  }

  /// Store and PickSell vouchers (or a typed code), as on the website's checkout.
  Future<void> _pickVouchers() async {
    final q = _quote;
    if (q == null) return;
    final result = await PsBottomSheet.show<VoucherSheetResult>(
      context,
      title: 'Vouchers',
      builder: (_) => Padding(
        padding: _sheetPadding,
        child: VoucherPickerSheet(
          vouchers: _vouchers,
          picks: _picks,
          sellerNames: {for (final g in q.groups) if (g.seller != null) g.seller!.id: g.seller!.name},
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _picks = result.picks);
    await _requote(code: result.code);
    if (mounted && result.code != null && _vouchers.error == null) PsToast.success(context, '${result.code!.toUpperCase()} applied');
  }

  final String _checkoutKey = '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';

  Future<void> _place() async {
    if (_placing || _quoting) return;
    if (_address?.complete != true) {
      await PsDialog.error(context,
          title: 'Add your delivery address',
          message: _addressId == null
              ? 'We deliver to the address in your profile. Add your province, city and barangay first.'
              : 'This address is missing its province, city or barangay. Finish it or pick another one.',
          actionLabel: 'Edit address');
      if (mounted) _editAddress();
      return;
    }
    setState(() => _placing = true);
    try {
      final placed = await _checkout.place(checkoutKey: _checkoutKey, lineIds: widget.lineIds, voucherCode: _voucher, addressId: _addressId, vouchers: _picks, carriers: _carriers);
      CartStore.instance.reset();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => OrderPlacedPage(result: placed)));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _placing = false);
      if (e.fieldError('item_ids') != null) {
        await PsDialog.error(context, title: 'Your cart changed', message: e.fieldError('item_ids')!, actionLabel: 'Back to cart');
        if (mounted) Navigator.of(context).pop();
      } else if (e.fieldError('address') != null) {
        await PsDialog.error(context, title: 'Add your delivery address', message: e.fieldError('address')!, actionLabel: 'Edit address');
        if (mounted) _editAddress();
      } else if (e.fieldError('vouchers') != null) {
        // Used up or no longer applies since the quote: show why and re-price without it.
        await PsDialog.error(context, title: 'A voucher can’t be used', message: e.fieldError('vouchers')!, actionLabel: 'Review vouchers');
        if (!mounted) return;
        setState(() => _picks = const VoucherPicks());
        await _requote();
        if (mounted) _pickVouchers();
      } else if (e.fieldError('address_id') != null) {
        _addressId = null;
        await PsDialog.error(context, title: 'Address no longer saved', message: 'That address was removed. Pick where to deliver this order.', actionLabel: 'Choose address');
        if (mounted) _changeAddress();
      } else {
        await PsDialog.error(
          context,
          title: e.isNetworkError ? 'Can’t reach Picksell' : 'Couldn’t place your order',
          message: e.message,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _quote;
    return PsAppShell(
      topBar: const PsTopBar(title: 'Order Summary'),
      footer: q == null
          ? null
          : _PlaceBar(total: _payable, saving: _vouchers.total, busy: _placing || _quoting, onPlace: q.hasIssues ? null : _place),
      body: _body(q),
    );
  }

  /// What blocks this order: the shipping check's own words, or the item problems.
  static String _issueMessage(CartQuote q) {
    final reasons = <String>[
      for (final g in q.groups)
        if (g.shippingProblem != null) g.shippingProblem!,
      if (q.lines.any((l) => !l.purchasable))
        'Some items are no longer available in the quantity you chose. Go back to your cart to adjust them.',
    ];
    return reasons.isEmpty ? 'This order can’t be placed right now. Go back to your cart and try again.' : reasons.join('\n\n');
  }

  Widget _body(CartQuote? q) {
    if (q == null) {
      if (_quoting) return const PsSkeletonList(itemCount: 4, thumbnail: false);
      final e = _error;
      return e is ApiException && e.isNetworkError
          ? PsOfflineState(onRetry: _requote)
          : PsErrorState(title: 'Couldn’t prepare checkout', message: errorMessage(e ?? ''), onRetry: _requote);
    }
    final address = _address;

    return ListView(
      padding: const EdgeInsets.all(PsSpace.gutter),
      children: [
        if (address == null || !address.complete)
          PsCard(
            title: 'Delivery Address',
            onTap: _editAddress,
            trailing: InkWell(onTap: _changeAddress, child: Text('Change', style: PsText.link)),
            child: Row(
              children: [
                Icon(Icons.add_location_alt_outlined, color: PsColors.primaryStrong),
                const SizedBox(width: PsSpace.sm),
                Expanded(child: Text(address == null || address.isDefault ? 'Add your delivery address' : 'Finish this address', style: PsText.link)),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          )
        else
          PsAddressCard(
            title: 'Delivery Address',
            name: address.recipientName,
            phone: address.displayPhone,
            address: address.fullAddress,
            label: address.isDefault ? null : address.label,
            isDefault: address.isDefault,
            landmark: address.pin == null ? null : 'Pinned on the map',
            onTap: _changeAddress,
            trailing: Padding(
              padding: const EdgeInsets.only(left: PsSpace.xs),
              child: InkWell(onTap: _changeAddress, child: Text('Change', style: PsText.link)),
            ),
          ),
        const SizedBox(height: PsSpace.sm),
        if (q.hasIssues)
          Padding(
            padding: const EdgeInsets.only(bottom: PsSpace.sm),
            child: PsCard(
              color: PsColors.errorSoft,
              borderColor: PsColors.error.withAlpha(80),
              child: Text(_issueMessage(q), style: PsText.caption.copyWith(color: PsColors.errorStrong, fontWeight: FontWeight.w600)),
            ),
          ),
        for (final g in q.groups) ...[
          PsOrderSummary(
            sellerName: g.seller?.name ?? 'Seller',
            verified: g.seller?.verified ?? false,
            lines: [
              for (final l in g.items)
                PsOrderLineRow(name: l.product.name, image: l.product.image, quantity: l.quantity, unitPrice: l.unitPrice, variationLabel: l.variationLabel),
            ],
            footer: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Subtotal: ${formatPesoFixed(g.subtotal)}', style: PsText.caption),
              if (g.discount > 0) Text('Product voucher: -${formatPesoFixed(g.discount)}', style: PsText.caption),
              TextButton(onPressed: _quoting ? null : _pickVouchers, child: Text('Store voucher: -${formatPesoFixed(g.storeDiscount)}')),
              Text('Shipping: ${formatPesoFixed(g.shippingFee)}', style: PsText.caption),
              if (g.platformDiscount + g.shippingDiscount > 0)
                Text('PickSell savings: -${formatPesoFixed(g.platformDiscount + g.shippingDiscount)}', style: PsText.caption),
              Text('Store total / COD: ${formatPesoFixed(g.storeTotal ?? (g.subtotal - g.discount + g.shippingFee))}', style: PsText.bodyStrong),
              const SizedBox(height: PsSpace.sm),
              if (g.carriers.length > 1)
                _CarrierPicker(
                    options: g.carriers,
                    busy: _quoting,
                    onPick: (c) {
                      final sellerId = g.seller?.id;
                      if (sellerId == null || c.selected || !c.ok) return;
                      setState(() => _carriers[sellerId] = c.id);
                      _requote();
                    },
                  )
              else if (g.deliveryLabel != null) Row(
                        children: [
                          Icon(Icons.local_shipping_outlined, size: 18, color: PsColors.textMuted),
                          const SizedBox(width: PsSpace.xs),
                          Expanded(child: Text('Arrives ${g.deliveryLabel}', style: PsText.caption)),
                        ],
                      ),
            ]),
          ),
          const SizedBox(height: PsSpace.sm),
        ],
        PsCard(
          title: 'Payment Method',
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: PsColors.surfaceMuted, borderRadius: BorderRadius.circular(8)),
                child: Icon(PsPaymentMethodTile.iconFor('cod')),
              ),
              const SizedBox(width: PsSpace.sm),
              Expanded(child: Text('Cash on Delivery', style: PsText.bodyStrong)),
              Icon(Icons.done_all_rounded, color: PsColors.primary),
            ],
          ),
        ),
        const SizedBox(height: PsSpace.sm),
        _VoucherRow(vouchers: _vouchers, onTap: _quoting ? null : _pickVouchers),
        const SizedBox(height: PsSpace.sm),
        PsCard(
          onTap: _enterVoucher,
          child: Row(
            children: [
              Icon(Icons.sell_outlined, color: PsColors.primaryStrong),
              const SizedBox(width: PsSpace.sm),
              Expanded(child: Text('Product voucher', style: PsText.bodyStrong)),
              if (q.voucher != null) PsTag('${q.voucher!.code} · -${formatPeso(q.voucher!.discount)}') else Text('Enter code', style: PsText.caption),
              Icon(Icons.chevron_right_rounded, color: PsColors.textMuted),
            ],
          ),
        ),
        const SizedBox(height: PsSpace.sm),
        PsCostBreakdown(
          totals: q.totals,
          voucherCode: q.voucher?.code,
          storeVoucherDiscount: _vouchers.storeSaving,
          pickSellVoucherDiscount: _vouchers.platformSaving,
        ),
        const SizedBox(height: PsSpace.sm),
        PsCard(
          color: PsColors.primarySoft,
          borderColor: PsColors.primarySoft,
          child: Row(
            children: [
              Icon(Icons.payments_outlined, size: 18, color: PsColors.primaryStrong),
              const SizedBox(width: PsSpace.xs),
              Expanded(
                child: Text('Total COD: ${formatPesoFixed(_payable)}. Each store has a separate order. Pay only for parcels delivered.',
                    style: PsText.caption.copyWith(color: PsColors.primaryStrong)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A product's own voucher code, as printed on its product page.
class VoucherCodeSheet extends StatefulWidget {
  const VoucherCodeSheet({super.key, this.initial});

  final String? initial;

  @override
  State<VoucherCodeSheet> createState() => VoucherCodeSheetState();
}

class VoucherCodeSheetState extends State<VoucherCodeSheet> {
  late final _code = TextEditingController(text: widget.initial ?? '');

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Owns its margins, so it looks the same from the cart and from checkout.
    return Padding(
      padding: const EdgeInsets.fromLTRB(PsSpace.gutter, PsSpace.xs, PsSpace.gutter, PsSpace.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Enter the voucher code shown on the product page. Codes are case-sensitive.', style: PsText.bodyMuted),
          const SizedBox(height: PsSpace.lg),
          PsTextField(
            label: 'Voucher code',
            hint: 'e.g. SAVE50',
            controller: _code,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => Navigator.of(context).pop(_code.text.trim()),
          ),
          const SizedBox(height: PsSpace.md),
          PsPrimaryButton(label: 'Apply', uppercase: false, onPressed: () => Navigator.of(context).pop(_code.text.trim())),
          if (widget.initial != null) ...[
            const SizedBox(height: PsSpace.sm),
            PsSecondaryButton.outlined(label: 'Remove voucher', expand: true, onPressed: () => Navigator.of(context).pop('')),
          ],
        ],
      ),
    );
  }
}

/// "Store & PickSell Vouchers" row: what's picked and saved, or how many are on offer.
class _VoucherRow extends StatelessWidget {
  const _VoucherRow({required this.vouchers, required this.onTap});

  final CheckoutVouchers vouchers;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final v = vouchers;
    final usable = [...v.platform, for (final s in v.stores) ...s.options].where((o) => o.usable).length;
    return PsCard(
      onTap: onTap,
      child: Row(
        children: [
          Icon(Icons.confirmation_number_outlined, color: PsColors.primaryStrong),
          const SizedBox(width: PsSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Store & PickSell Vouchers', style: PsText.bodyStrong),
                if (v.pickedCount > 0)
                  Text(v.pickedCodes.join(' · '), style: PsText.caption)
                else
                  Text(usable > 0 ? '$usable available for this order' : 'Enter a voucher code', style: PsText.caption),
              ],
            ),
          ),
          if (v.total > 0) PsTag('-${formatPesoFixed(v.total)}') else if (usable > 0) const PsTag('SELECT'),
          Icon(Icons.chevron_right_rounded, color: PsColors.textMuted),
        ],
      ),
    );
  }
}

class _PlaceBar extends StatelessWidget {
  const _PlaceBar({required this.total, required this.busy, required this.onPlace, this.saving = 0});

  final double total;

  /// Saved with store and PickSell vouchers.
  final double saving;
  final bool busy;
  final VoidCallback? onPlace;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: PsColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: PsColors.border)),
        boxShadow: PsColors.isDark ? null : const [BoxShadow(color: Color(0x141B1B1B), blurRadius: 24, offset: Offset(0, -6))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(PsSpace.gutter, PsSpace.sm, PsSpace.gutter, PsSpace.sm),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Amount', style: PsText.caption),
                    Text(formatPesoFixed(total), style: PsText.price.copyWith(fontSize: 20)),
                    if (saving > 0) Text('You save ${formatPesoFixed(saving)}', style: PsText.caption.copyWith(color: PsColors.primaryStrong)),
                  ],
                ),
              ),
              SizedBox(
                width: 180,
                child: PsPrimaryButton(label: 'Place Order', uppercase: false, loading: busy, onPressed: onPlace),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Ship with": the logistics companies one store's parcel can go with
/// (website checkout), each with its fee and arrival window.
class _CarrierPicker extends StatelessWidget {
  const _CarrierPicker({required this.options, required this.onPick, this.busy = false});

  final List<CarrierOption> options;
  final ValueChanged<CarrierOption> onPick;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Ship with', style: PsText.ui.copyWith(fontSize: 13)),
        const SizedBox(height: PsSpace.xs),
        for (final c in options) ...[
          Semantics(
            inMutuallyExclusiveGroup: true,
            checked: c.selected,
            enabled: c.ok,
            button: true,
            label: [c.name, if (c.isDefault) 'recommended', if (c.ok) formatPesoFixed(c.fee), c.ok ? (c.etaLabel ?? '') : (c.message ?? 'Not available')].join(', '),
            excludeSemantics: true,
            child: Opacity(
              opacity: c.ok ? 1 : 0.55,
              child: Material(
                color: c.selected ? PsColors.primarySoft : PsColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: c.selected ? PsColors.primary : PsColors.border, width: c.selected ? 1.6 : 1),
                ),
                child: InkWell(
                  onTap: busy || !c.ok || c.selected ? null : () => onPick(c),
                  customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: PsSpace.sm, vertical: 10),
                    child: Row(
                      children: [
                        Icon(c.selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                            size: 20, color: c.selected ? PsColors.textPrimary : PsColors.textMuted),
                        const SizedBox(width: PsSpace.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(child: Text(c.name, style: PsText.ui.copyWith(fontSize: 14), overflow: TextOverflow.ellipsis)),
                                  if (c.isDefault) ...[const SizedBox(width: 6), const PsTag('RECOMMENDED')],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                c.ok ? (c.etaLabel == null ? 'Date shown after ordering' : 'Arrives ${c.etaLabel}') : (c.message ?? 'Not available for this parcel'),
                                style: PsText.caption.copyWith(color: c.ok ? null : PsColors.errorStrong),
                              ),
                            ],
                          ),
                        ),
                        if (c.ok) Text(formatPesoFixed(c.fee), style: PsText.price.copyWith(fontSize: 15)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: PsSpace.xs),
        ],
      ],
    );
  }
}
