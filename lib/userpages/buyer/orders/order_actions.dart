import 'package:flutter/material.dart';

import '../../../components/components.dart';
import '../../../models/order.dart';
import '../../../services/cart_service.dart';
import '../../../services/order_service.dart';
import '../nav.dart';
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

/// Star rating + optional comment. Resolves with the updated order.
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
    if (_rating == 0) {
      setState(() => _error = 'Tap a star to rate.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final o = await OrderService().rate(widget.orderId, rating: _rating, feedback: _comment.text);
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(PsSpace.gutter, 0, PsSpace.gutter, PsSpace.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.productName, style: PsText.bodyMuted, textAlign: TextAlign.center),
          const SizedBox(height: PsSpace.xs),
          Center(child: PsRatingStars(rating: _rating.toDouble(), size: 34, onChanged: (v) => setState(() => _rating = v))),
          Text(_labels[_rating], textAlign: TextAlign.center, style: PsText.bodyStrong),
          const SizedBox(height: PsSpace.sm),
          TextField(
            controller: _comment,
            maxLines: 4,
            maxLength: 1000,
            style: PsText.input,
            decoration: psInputDecoration(hint: 'Share what you liked or didn’t (optional)'),
          ),
          if (_error != null) PsFieldError(_error!),
          const SizedBox(height: PsSpace.sm),
          PsPrimaryButton(label: 'Submit review', uppercase: false, loading: _busy, onPressed: _submit),
        ],
      ),
    );
  }
}
