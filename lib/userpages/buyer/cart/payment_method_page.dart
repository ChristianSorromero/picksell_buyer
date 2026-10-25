import 'package:flutter/material.dart';

import '../../../components/components.dart';
import '../../../models/address.dart';
import '../../../models/cart.dart';
import '../../../services/checkout_service.dart';

/// COM-C16 Payment Method picker (also BUY-A04 from Account, where it's
/// read-only). Only methods the backend marks available can be chosen.
class PaymentMethodPage extends StatefulWidget {
  const PaymentMethodPage({super.key, this.selected = 'cod', this.billingAddress, this.readOnly = false});

  final String selected;
  final Address? billingAddress;
  final bool readOnly;

  @override
  State<PaymentMethodPage> createState() => _PaymentMethodPageState();
}

class _PaymentMethodPageState extends State<PaymentMethodPage> {
  late String _selected = widget.selected;

  @override
  Widget build(BuildContext context) {
    return PsAppShell(
      topBar: PsTopBar(title: widget.readOnly ? 'Payment Methods' : 'Payment Method'),
      footer: widget.readOnly
          ? null
          : PsFooterActions(primary: PsPrimaryButton(label: 'Confirm', uppercase: false, onPressed: () => Navigator.of(context).pop(_selected))),
      body: PsAsyncView<List<PaymentMethodOption>>(
        load: CheckoutService().paymentMethods,
        builder: (context, methods, _) => ListView(
          padding: const EdgeInsets.all(PsSpace.gutter),
          children: [
            Text(widget.readOnly ? 'Supported payment methods' : 'Select Payment Method', style: PsText.heading.copyWith(fontSize: 16)),
            const SizedBox(height: PsSpace.xs),
            for (final m in methods) ...[
              PsPaymentMethodTile(
                method: m,
                selected: m.code == _selected,
                onTap: () {
                  if (!widget.readOnly) setState(() => _selected = m.code);
                },
              ),
              const SizedBox(height: PsSpace.sm),
            ],
            if (widget.readOnly)
              Text('Cash on Delivery is used for every order for now. Digital wallets and cards are coming soon.',
                  style: PsText.caption, textAlign: TextAlign.center),
            if (widget.billingAddress != null) ...[
              const SizedBox(height: PsSpace.sm),
              Text('Billing Address', style: PsText.heading.copyWith(fontSize: 16)),
              const SizedBox(height: PsSpace.xs),
              PsAddressCard.of(widget.billingAddress!),
            ],
          ],
        ),
      ),
    );
  }
}
