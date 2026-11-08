import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../components/components.dart';
import '../../../format_utils.dart';
import '../../../services/order_service.dart';

/// The rider's photo at the door (website: order page "Proof of delivery").
/// It's private, so it is downloaded with the buyer's login, not by URL.
class DeliveryProofCard extends StatefulWidget {
  const DeliveryProofCard({super.key, required this.orderId, this.riderName, this.deliveredAt, this.service});

  final int orderId;
  final String? riderName;
  final DateTime? deliveredAt;

  /// Injected in tests.
  final OrderService? service;

  @override
  State<DeliveryProofCard> createState() => _DeliveryProofCardState();
}

class _DeliveryProofCardState extends State<DeliveryProofCard> {
  late final _service = widget.service ?? OrderService();
  Uint8List? _photo;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final bytes = await _service.proofOfDelivery(widget.orderId);
      if (mounted) setState(() => _photo = bytes);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _open() {
    final photo = _photo;
    if (photo == null) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(PsSpace.md),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            InteractiveViewer(child: Image.memory(photo, fit: BoxFit.contain)),
            Positioned(
              right: 4,
              top: 4,
              child: IconButton.filledTonal(tooltip: 'Close', onPressed: () => Navigator.of(ctx).pop(), icon: const Icon(Icons.close_rounded)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final who = widget.riderName == null ? 'the rider' : widget.riderName!;
    return PsCard(
      title: 'Proof of Delivery',
      onTap: _photo == null ? (_error != null ? _load : null) : _open,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox.square(
              dimension: 72,
              child: _photo != null
                  ? Image.memory(_photo!, fit: BoxFit.cover, semanticLabel: 'Delivery photo')
                  : ColoredBox(
                      color: PsColors.surfaceMuted,
                      child: Center(
                        child: _error == null
                            ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.refresh_rounded, color: PsColors.textMuted),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: PsSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Photo taken by $who', style: PsText.bodyStrong),
                if (widget.deliveredAt != null) Text(formatDateTime(widget.deliveredAt!), style: PsText.caption),
                const SizedBox(height: 2),
                Text(
                  _error != null ? 'Couldn’t load the photo. Tap to try again.' : (_photo == null ? 'Loading photo…' : 'Tap to view full photo'),
                  style: _error != null ? PsText.caption.copyWith(color: PsColors.error) : PsText.link,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
