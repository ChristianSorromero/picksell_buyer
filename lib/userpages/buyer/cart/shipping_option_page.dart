import 'package:flutter/material.dart';

import '../../../components/components.dart';
import '../../../models/address.dart';
import '../../../models/catalog.dart';
import '../../../services/checkout_service.dart';

/// COM-C15 Shipping Option picker. Pops with the chosen code.
class ShippingOptionPage extends StatefulWidget {
  const ShippingOptionPage({super.key, required this.selected, this.address, this.parcels = 1});

  final String selected;
  final Address? address;
  final int parcels;

  @override
  State<ShippingOptionPage> createState() => _ShippingOptionPageState();
}

class _ShippingOptionPageState extends State<ShippingOptionPage> {
  late String _selected = widget.selected;

  @override
  Widget build(BuildContext context) {
    return PsAppShell(
      topBar: const PsTopBar(title: 'Shipping Option'),
      footer: PsFooterActions(primary: PsPrimaryButton(label: 'Confirm', uppercase: false, onPressed: () => Navigator.of(context).pop(_selected))),
      body: PsAsyncView<List<ShippingOption>>(
        load: CheckoutService().shippingOptions,
        builder: (context, options, _) => ListView(
          padding: const EdgeInsets.all(PsSpace.gutter),
          children: [
            if (widget.address != null) ...[
              Text('Delivery Address', style: PsText.heading.copyWith(fontSize: 16)),
              const SizedBox(height: PsSpace.xs),
              PsAddressCard.of(widget.address!),
              const SizedBox(height: PsSpace.lg),
            ],
            Text('Select Shipping Method', style: PsText.heading.copyWith(fontSize: 16)),
            if (widget.parcels > 1)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Your order ships as ${widget.parcels} parcels (one per seller); the fee applies to each.', style: PsText.caption),
              ),
            const SizedBox(height: PsSpace.xs),
            for (final o in options) ...[
              PsShippingOptionTile(
                option: o,
                parcels: widget.parcels,
                selected: o.code == _selected,
                onTap: () => setState(() => _selected = o.code),
              ),
              const SizedBox(height: PsSpace.sm),
            ],
          ],
        ),
      ),
    );
  }
}
