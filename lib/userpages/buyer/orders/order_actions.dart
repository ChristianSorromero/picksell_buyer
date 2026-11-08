import 'package:flutter/material.dart';

import '../../../components/components.dart';
import '../../../models/order.dart';
import '../../../services/cart_service.dart';
import '../../../services/order_service.dart';
import '../nav.dart';
import 'evidence_picker.dart';
import 'track_order_page.dart';

/// Shared order actions used by the list, details and tracking screens.

Future<void> openTracking(BuildContext context, int orderId) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => TrackOrderPage(orderId: orderId)));

/// BUY-C13 — adds the item back at today's price and offers the cart.
Future<void> buyAgain(BuildContext context, int orderId) async {
  try {
    final r = await OrderService().reorder(orderId);
    CartStore.instance.refreshCount();
    if (!context.mounted) return;
    PsToast.show(
      context,
      r.priceChanged ? '${r.message} The price has changed since your last order.' : r.message,
      type: PsToastType.success,
      actionLabel: 'View Cart',
      onAction: () => ShellNav.goTo(context, BuyerTab.cart),
    );
  } catch (e) {
    if (context.mounted) PsDialog.error(context, title: 'Can’t reorder this item', message: errorMessage(e));
  }
}

/// "Order Received" (website: My Orders): the buyer confirms the delivered parcel reached them,
/// which completes the order, then goes straight on to rating it. Resolves with the updated
/// order (rated or not), or null when they backed out.
Future<OrderDetail?> confirmReceived(BuildContext context, int orderId, String productName) async {
  final ok = await PsDialog.confirm(
    context,
    title: 'Got your order?',
    message: 'Confirm only once the parcel is in your hands and you’ve checked it. The seller then gets paid, and you can rate your order.',
    confirmLabel: 'Yes, I received it',
    cancelLabel: 'Not yet',
    icon: Icons.inventory_2_outlined,
  );
  if (!ok || !context.mounted) return null;
  try {
    final done = await OrderService().confirmReceived(orderId);
    if (!context.mounted) return done;
    PsToast.success(context, 'Thanks for confirming! Rate your order now.');
    return await rateOrder(context, orderId, productName) ?? done;
  } on ApiException catch (e) {
    if (context.mounted) PsDialog.error(context, title: 'Couldn’t confirm', message: e.message);
    return null;
  }
}

/// The website's rating: product, seller and delivery stars, an optional comment and up to
/// 3 photos, after "Order Received". Resolves with the updated order.
Future<OrderDetail?> rateOrder(BuildContext context, int orderId, String productName) {
  return PsBottomSheet.show<OrderDetail>(
    context,
    title: 'Rate your order',
    builder: (_) => _RateSheet(orderId: orderId, productName: productName),
  );
}

class _RateSheet extends StatefulWidget {
  const _RateSheet({required this.orderId, required this.productName});

  final int orderId;
  final String productName;

  @override
  State<_RateSheet> createState() => _RateSheetState();
}

class _RateSheetState extends State<_RateSheet> {
  int _rating = 0;
  int _sellerRating = 0;
  int _deliveryRating = 0;
  List<String> _photos = [];
  final _comment = TextEditingController();
  String? _error;
  bool _busy = false;

  static const _labels = ['', 'Poor', 'Fair', 'Good', 'Very good', 'Excellent'];

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Same messages as the website's rating form.
    final missing = _rating == 0
        ? 'Rate the product.'
        : _sellerRating == 0
            ? 'Rate the seller’s service.'
            : _deliveryRating == 0
                ? 'Rate the delivery.'
                : null;
    if (missing != null) {
      setState(() => _error = missing);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final o = await OrderService().rate(
        widget.orderId,
        rating: _rating,
        sellerRating: _sellerRating,
        deliveryRating: _deliveryRating,
        feedback: _comment.text,
        photos: _photos,
      );
      if (!mounted) return;
      PsToast.success(context, 'Thanks for your review!');
      Navigator.of(context).pop(o);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = errorMessage(e);
        });
      }
    }
  }

  Widget _stars(String label, int value, ValueChanged<int> onChanged, {double size = 30}) => Column(
        children: [
          Text(label, style: PsText.bodyStrong, textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Semantics(
            label: '$label, ${value == 0 ? 'not rated' : '$value of 5'}',
            child: PsRatingStars(rating: value.toDouble(), size: size, onChanged: onChanged),
          ),
          Text(_labels[value], style: PsText.caption, textAlign: TextAlign.center),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(PsSpace.gutter, 0, PsSpace.gutter, PsSpace.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.productName, style: PsText.bodyMuted, textAlign: TextAlign.center),
          const SizedBox(height: PsSpace.xs),
          _stars('Product', _rating, (v) => setState(() => _rating = v), size: 34),
          const SizedBox(height: PsSpace.sm),
          _stars('Seller’s service', _sellerRating, (v) => setState(() => _sellerRating = v)),
          const SizedBox(height: PsSpace.sm),
          _stars('Delivery', _deliveryRating, (v) => setState(() => _deliveryRating = v)),
          const SizedBox(height: PsSpace.sm),
          TextField(
            controller: _comment,
            maxLines: 4,
            maxLength: 1000,
            style: PsText.input,
            decoration: psInputDecoration(hint: 'Share what you liked or didn’t (optional)'),
          ),
          Text('Photos (optional, up to 3)', style: PsText.caption),
          const SizedBox(height: PsSpace.xs),
          EvidencePicker(paths: _photos, onChanged: (p) => setState(() => _photos = p)),
          if (_error != null) PsFieldError(_error!),
          const SizedBox(height: PsSpace.sm),
          PsPrimaryButton(label: 'Submit review', uppercase: false, loading: _busy, onPressed: _submit),
        ],
      ),
    );
  }
}
