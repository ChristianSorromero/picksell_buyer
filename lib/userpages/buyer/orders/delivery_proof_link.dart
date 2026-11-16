import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../components/components.dart';
import '../../../format_utils.dart';
import '../../../services/order_service.dart';

/// "View proof of delivery" under the shipment history — the one place the
/// buyer opens the rider's photo at the door (website: order page "Proof of
/// delivery"). The photo is private, so it downloads with the buyer's login
/// when opened, not by URL.
class DeliveryProofLink extends StatelessWidget {
  const DeliveryProofLink({super.key, required this.orderId, this.riderName, this.deliveredAt, this.service});

  final int orderId;
  final String? riderName;
  final DateTime? deliveredAt;

  /// Injected in tests.
  final OrderService? service;

  @override
  Widget build(BuildContext context) {
    return PsCard(
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => _ProofDialog(orderId: orderId, riderName: riderName, deliveredAt: deliveredAt, service: service ?? OrderService()),
      ),
      child: Row(
        children: [
          Icon(Icons.photo_camera_outlined, color: PsColors.primary),
          const SizedBox(width: PsSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('View proof of delivery', style: PsText.link),
                if (deliveredAt != null) Text('Delivered ${formatDateTime(deliveredAt!)}', style: PsText.caption),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: PsColors.textMuted),
        ],
      ),
    );
  }
}

class _ProofDialog extends StatefulWidget {
  const _ProofDialog({required this.orderId, required this.service, this.riderName, this.deliveredAt});

  final int orderId;
  final OrderService service;
  final String? riderName;
  final DateTime? deliveredAt;

  @override
  State<_ProofDialog> createState() => _ProofDialogState();
}

class _ProofDialogState extends State<_ProofDialog> {
  late Future<Uint8List> _photo = widget.service.proofOfDelivery(widget.orderId);

  @override
  Widget build(BuildContext context) {
    final who = widget.riderName ?? 'the rider';
    return Dialog(
      insetPadding: const EdgeInsets.all(PsSpace.md),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(PsSpace.md, PsSpace.xs, 4, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Proof of Delivery', style: PsText.bodyStrong),
                      Text(
                        ['Photo taken by $who', if (widget.deliveredAt != null) formatDateTime(widget.deliveredAt!)].join(' · '),
                        style: PsText.caption,
                      ),
                    ],
                  ),
                ),
                IconButton(tooltip: 'Close', onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded)),
              ],
            ),
          ),
          FutureBuilder<Uint8List>(
            future: _photo,
            builder: (context, snap) {
              if (snap.hasData) {
                return Flexible(
                  child: InteractiveViewer(
                    maxScale: 5,
                    child: Image.memory(snap.data!, fit: BoxFit.contain, semanticLabel: 'Delivery photo'),
                  ),
                );
              }
              return SizedBox(
                height: 220,
                child: Center(
                  child: snap.hasError
                      ? TextButton.icon(
                          onPressed: () => setState(() => _photo = widget.service.proofOfDelivery(widget.orderId)),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Couldn’t load the photo. Try again'),
                        )
                      : const CircularProgressIndicator(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
