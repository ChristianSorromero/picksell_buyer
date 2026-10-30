import 'package:flutter/material.dart';

import '../../../components/components.dart';
import '../../../format_utils.dart';
import '../../../models/address.dart';
import '../../../models/cart.dart';
import '../../../services/cart_service.dart';
import '../../../services/checkout_service.dart';
import '../account/edit_profile_page.dart';
import 'order_placed_page.dart';

/// Order Summary / Checkout (COM-C14…C19) with the website's checkout rules:
/// delivered to the buyer's profile address, Cash on Delivery, priced by the
/// product discount and the product's own voucher code. No delivery fee.
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
  DeliveryAddress? _address;
  late String? _voucher = widget.voucherCode;
  Object? _error;
  bool _quoting = true;
  bool _placing = false;

  @override
  void initState() {
    super.initState();
    _requote();
  }

  Future<void> _requote() async {
    setState(() => _quoting = true);
    try {
      final r = await _checkout.quote(lineIds: widget.lineIds, voucherCode: _voucher);
      if (!mounted) return;
      setState(() {
        _quote = r.quote;
        _address = r.deliveryAddress;
        _error = null;
        if (r.quote.voucherError != null) _voucher = null;
      });
      if (r.quote.voucherError != null) PsToast.error(context, r.quote.voucherError!);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _quoting = false);
    }
  }

  Future<void> _editAddress() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EditProfilePage(focusAddress: true)));
    if (mounted) _requote();
  }

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

  Future<void> _place() async {
    if (_address?.complete != true) {
      await PsDialog.error(context,
          title: 'Add your delivery address',
          message: 'We deliver to the address in your profile. Add your province, city and barangay first.',
          actionLabel: 'Edit address');
      if (mounted) _editAddress();
      return;
    }
    setState(() => _placing = true);
    try {
      final placed = await _checkout.place(lineIds: widget.lineIds, voucherCode: _voucher);
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
    final address = _address;

    return ListView(
      padding: const EdgeInsets.all(PsSpace.gutter),
      children: [
        if (address == null || !address.complete)
          PsCard(
            title: 'Delivery Address',
            onTap: _editAddress,
            child: Row(
              children: [
                const Icon(Icons.add_location_alt_outlined, color: PsColors.primaryStrong),
                const SizedBox(width: PsSpace.sm),
                Expanded(child: Text('Add your delivery address', style: PsText.link)),
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
            onEdit: _editAddress,
          ),
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
              const Icon(Icons.done_all_rounded, color: PsColors.primary),
            ],
          ),
        ),
        const SizedBox(height: PsSpace.sm),
        PsCard(
          onTap: _enterVoucher,
          child: Row(
            children: [
              const Icon(Icons.confirmation_number_outlined, color: PsColors.primaryStrong),
              const SizedBox(width: PsSpace.sm),
              Expanded(child: Text('Voucher', style: PsText.bodyStrong)),
              if (q.voucher != null) PsTag('${q.voucher!.code} · -${formatPeso(q.voucher!.discount)}') else Text('Enter code', style: PsText.caption),
              const Icon(Icons.chevron_right_rounded, color: PsColors.textMuted),
            ],
          ),
        ),
        const SizedBox(height: PsSpace.sm),
        PsCostBreakdown(totals: q.totals, voucherCode: q.voucher?.code),
        const SizedBox(height: PsSpace.sm),
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Enter the voucher code shown on the product page. Codes are case-sensitive.', style: PsText.caption),
        const SizedBox(height: PsSpace.sm),
        PsTextField(label: 'Voucher code', controller: _code, textInputAction: TextInputAction.done),
        const SizedBox(height: PsSpace.md),
        PsPrimaryButton(label: 'Apply', uppercase: false, onPressed: () => Navigator.of(context).pop(_code.text.trim())),
        if (widget.initial != null) ...[
          const SizedBox(height: PsSpace.xs),
          PsSecondaryButton(label: 'Remove voucher', onPressed: () => Navigator.of(context).pop('')),
        ],
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
