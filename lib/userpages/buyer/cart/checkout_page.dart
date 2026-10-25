import 'package:flutter/material.dart';

import '../../../components/components.dart';
import '../../../format_utils.dart';
import '../../../models/address.dart';
import '../../../models/cart.dart';
import '../../../services/account_service.dart';
import '../../../services/cart_service.dart';
import '../../../services/checkout_service.dart';
import '../account/address_book_page.dart';
import '../account/address_form_page.dart';
import 'order_placed_page.dart';
import 'payment_method_page.dart';
import 'shipping_option_page.dart';

/// Order Summary / Checkout (COM-C14…C19): address, items per seller,
/// shipping, payment, voucher and server-priced totals → Place Order.
class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key, required this.lineIds, this.voucherCode});

  final List<int> lineIds;
  final String? voucherCode;

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _checkout = CheckoutService();
  final _account = AccountService();

  CartQuote? _quote;
  Address? _address;
  bool _addressLoaded = false;
  String _shipping = 'standard';
  String _payment = 'cod';
  late String? _voucher = widget.voucherCode;
  Object? _error;
  bool _quoting = true;
  bool _placing = false;

  @override
  void initState() {
    super.initState();
    _loadAddress();
    _requote();
  }

  Future<void> _loadAddress() async {
    try {
      final list = await _account.addresses();
      if (!mounted) return;
      setState(() {
        _address = list.where((a) => a.isDefault).firstOrNull ?? list.firstOrNull;
        _addressLoaded = true;
      });
    } catch (e) {
      if (mounted) setState(() => _addressLoaded = true);
    }
  }

  Future<void> _requote() async {
    setState(() => _quoting = true);
    try {
      final q = await _checkout.quote(lineIds: widget.lineIds, shippingOption: _shipping, voucherCode: _voucher);
      if (!mounted) return;
      setState(() {
        _quote = q;
        _error = null;
        if (q.voucherError != null) _voucher = null;
      });
      if (q.voucherError != null) PsToast.error(context, q.voucherError!);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _quoting = false);
    }
  }

  Future<void> _chooseAddress() async {
    final picked = await Navigator.of(context).push<Address>(
      MaterialPageRoute(builder: (_) => AddressBookPage(selectMode: true, selectedId: _address?.id)),
    );
    if (picked != null && mounted) setState(() => _address = picked);
  }

  Future<void> _addAddress() async {
    final created = await Navigator.of(context).push<Address>(MaterialPageRoute(builder: (_) => const AddressFormPage()));
    if (created != null && mounted) setState(() => _address = created);
  }

  Future<void> _chooseShipping() async {
    final code = await Navigator.of(context).push<String>(MaterialPageRoute(
      builder: (_) => ShippingOptionPage(selected: _shipping, address: _address, parcels: _quote?.groups.length ?? 1),
    ));
    if (code != null && code != _shipping) {
      setState(() => _shipping = code);
      _requote();
    }
  }

  Future<void> _choosePayment() async {
    final code = await Navigator.of(context).push<String>(MaterialPageRoute(
      builder: (_) => PaymentMethodPage(selected: _payment, billingAddress: _address),
    ));
    if (code != null) setState(() => _payment = code);
  }

  Future<void> _chooseVoucher() async {
    final code = await PsBottomSheet.show<String>(
      context,
      title: 'Select Voucher',
      builder: (_) => PsVoucherSheet(
        selectedCode: _voucher,
        load: () async {
          final d = await _checkout.vouchersFor(widget.lineIds);
          return (platform: d.platform, store: d.store);
        },
      ),
    );
    if (code == null) return;
    setState(() => _voucher = code.isEmpty ? null : code);
    _requote();
  }

  Future<void> _place() async {
    final address = _address;
    if (address == null) {
      await PsDialog.error(context, title: 'Add a delivery address', message: 'We need to know where to deliver your order.', actionLabel: 'Add address');
      if (mounted) _addAddress();
      return;
    }
    setState(() => _placing = true);
    try {
      final placed = await _checkout.place(
        lineIds: widget.lineIds,
        addressId: address.id,
        paymentMethod: _payment,
        shippingOption: _shipping,
        voucherCode: _voucher,
      );
      CartStore.instance.reset();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => OrderPlacedPage(result: placed)));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _placing = false);
      if (e.statusCode == 409) {
        await PsDialog.error(context, title: 'Your cart changed', message: e.message, actionLabel: 'Back to cart');
        if (mounted) Navigator.of(context).pop();
      } else if (e.fieldError('voucher_code') != null) {
        setState(() => _voucher = null);
        await PsDialog.error(context, title: 'Voucher can’t be used', message: e.fieldError('voucher_code')!);
        _requote();
      } else {
        await PsDialog.error(
          context,
          title: e.isNetworkError ? 'Can’t reach Picksell' : 'Couldn’t place your order',
          message: e.fieldError('address_id') ?? e.fieldError('payment_method') ?? e.message,
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
          : _PlaceBar(total: q.totals.total, busy: _placing || _quoting, onPlace: q.hasIssues ? null : _place),
      body: _body(q),
    );
  }

  Widget _body(CartQuote? q) {
    if (q == null) {
      if (_quoting) return const PsSkeletonList(itemCount: 4, thumbnail: false);
      final e = _error;
      return e is ApiException && e.isNetworkError
          ? PsOfflineState(onRetry: _requote)
          : PsErrorState(title: 'Couldn’t prepare checkout', message: errorMessage(e ?? ''), onRetry: _requote);
    }
    final shipping = q.shippingOption;
    final paymentName = _payment == 'cod' ? 'Cash on Delivery' : _payment;

    return ListView(
      padding: const EdgeInsets.all(PsSpace.gutter),
      children: [
        if (!_addressLoaded)
          const PsCard(child: SizedBox(height: 56, child: PsLoadingState()))
        else if (_address == null)
          PsCard(
            title: 'Shipping Address',
            onTap: _addAddress,
            child: Row(
              children: [
                const Icon(Icons.add_location_alt_outlined, color: PsColors.primaryStrong),
                const SizedBox(width: PsSpace.sm),
                Expanded(child: Text('Add a delivery address', style: PsText.link)),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          )
        else
          PsAddressCard.of(_address!, title: 'Shipping Address', onEdit: _chooseAddress),
        const SizedBox(height: PsSpace.sm),
        if (q.hasIssues)
          Padding(
            padding: const EdgeInsets.only(bottom: PsSpace.sm),
            child: PsCard(
              color: PsColors.errorSoft,
              borderColor: PsColors.error.withAlpha(80),
              child: Text('Some items are no longer available in the quantity you chose. Go back to your cart to adjust them.',
                  style: PsText.caption.copyWith(color: PsColors.error, fontWeight: FontWeight.w600)),
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
            footer: Row(
              children: [
                Text('Shipping fee', style: PsText.caption),
                const Spacer(),
                Text(formatPesoFixed(g.shippingFee), style: PsText.caption.copyWith(fontWeight: FontWeight.w700, color: PsColors.textPrimary)),
              ],
            ),
          ),
          const SizedBox(height: PsSpace.sm),
        ],
        PsCard(
          title: 'Shipping Method',
          onTap: _chooseShipping,
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(color: PsColors.primarySoft, shape: BoxShape.circle),
                child: const Icon(Icons.local_shipping_rounded, color: PsColors.primaryStrong),
              ),
              const SizedBox(width: PsSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(shipping?.name ?? 'Standard', style: PsText.bodyStrong),
                    if (shipping != null) Text('Est. Delivery: ${formatDateRange(shipping.estimatedFrom, shipping.estimatedTo)}', style: PsText.caption),
                  ],
                ),
              ),
              Text(formatPesoFixed(q.totals.shippingTotal), style: PsText.bodyStrong),
              const Icon(Icons.chevron_right_rounded, color: PsColors.textMuted),
            ],
          ),
        ),
        const SizedBox(height: PsSpace.sm),
        PsCard(
          title: 'Payment Method',
          onTap: _choosePayment,
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: PsColors.surfaceMuted, borderRadius: BorderRadius.circular(8)),
                child: Icon(PsPaymentMethodTile.iconFor(_payment)),
              ),
              const SizedBox(width: PsSpace.sm),
              Expanded(child: Text(paymentName, style: PsText.bodyStrong)),
              const Icon(Icons.done_all_rounded, color: PsColors.primary),
              const Icon(Icons.chevron_right_rounded, color: PsColors.textMuted),
            ],
          ),
        ),
        const SizedBox(height: PsSpace.sm),
        PsCard(
          onTap: _chooseVoucher,
          child: Row(
            children: [
              const Icon(Icons.confirmation_number_outlined, color: PsColors.primaryStrong),
              const SizedBox(width: PsSpace.sm),
              Expanded(child: Text('Voucher', style: PsText.bodyStrong)),
              if (q.voucher != null) PsTag('${q.voucher!.code} · -${formatPeso(q.voucher!.discount)}') else Text('Select or enter code', style: PsText.caption),
              const Icon(Icons.chevron_right_rounded, color: PsColors.textMuted),
            ],
          ),
        ),
        const SizedBox(height: PsSpace.sm),
        PsCostBreakdown(totals: q.totals, voucherCode: q.voucher?.code),
        const SizedBox(height: PsSpace.sm),
        if (_payment == 'cod')
          PsCard(
            color: PsColors.primarySoft,
            borderColor: PsColors.primarySoft,
            child: Row(
              children: [
                const Icon(Icons.payments_outlined, size: 18, color: PsColors.primaryStrong),
                const SizedBox(width: PsSpace.xs),
                Expanded(
                  child: Text('Prepare ${formatPesoFixed(q.totals.total)} in cash for the rider.',
                      style: PsText.caption.copyWith(color: PsColors.primaryStrong)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PlaceBar extends StatelessWidget {
  const _PlaceBar({required this.total, required this.busy, required this.onPlace});

  final double total;
  final bool busy;
  final VoidCallback? onPlace;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: PsColors.surface, border: Border(top: BorderSide(color: PsColors.border))),
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

