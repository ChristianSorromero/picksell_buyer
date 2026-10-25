import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/status/order_status.dart';
import '../../core/theme/ps_colors.dart';
import '../../core/theme/ps_tokens.dart';
import '../../core/theme/ps_typography.dart';
import '../../format_utils.dart';
import '../../models/order.dart';
import '../shared/ps_card.dart';
import '../shared/ps_status_badge.dart';
import '../shared/ps_toast.dart';

/// BUY-C01 Order Status Header — buyer-facing headline for the canonical
/// state plus the latest real event description.
class PsOrderStatusHeader extends StatelessWidget {
  const PsOrderStatusHeader({super.key, required this.order});

  final OrderDetail order;

  @override
  Widget build(BuildContext context) {
    final latest = order.events.isEmpty ? null : order.events.last;
    final color = order.status.tone.foreground;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(order.status.buyerLabel, style: PsText.display.copyWith(fontSize: 26, color: order.status.isException ? color : null))),
            PsStatusBadge.order(order.status, pill: true),
          ],
        ),
        if (latest?.description != null) ...[
          const SizedBox(height: 6),
          Text(latest!.description!, style: PsText.subtitle),
        ],
      ],
    );
  }
}

/// Compact 4-node progress (Order Details): PLACED · SHIPPED · ARRIVED · DELIVERED.
class PsOrderProgressBar extends StatelessWidget {
  const PsOrderProgressBar({super.key, required this.status});

  final OrderStatus status;

  static const _steps = [
    ('PLACED', OrderStatus.placed),
    ('SHIPPED', OrderStatus.pickedUp),
    ('ARRIVED', OrderStatus.outForDelivery),
    ('DELIVERED', OrderStatus.delivered),
  ];

  @override
  Widget build(BuildContext context) {
    final at = OrderStatus.happyPath.indexOf(status);
    int reached = 0;
    for (var i = 0; i < _steps.length; i++) {
      if (at >= OrderStatus.happyPath.indexOf(_steps[i].$2)) reached = i;
    }
    if (status.isException) reached = -1;

    return Semantics(
      label: status.isException ? status.buyerLabel : 'Progress: ${_steps[reached < 0 ? 0 : reached].$1.toLowerCase()}',
      excludeSemantics: true,
      child: Row(
        children: [
          for (var i = 0; i < _steps.length; i++) ...[
            Column(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i <= reached ? PsColors.primary : PsColors.border,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [BoxShadow(color: (i <= reached ? PsColors.primary : PsColors.border).withAlpha(90), blurRadius: 4)],
                  ),
                  child: i == reached && i == _steps.length - 1 ? const Icon(Icons.check_rounded, size: 12, color: Colors.white) : null,
                ),
                const SizedBox(height: 6),
                Text(_steps[i].$1, style: PsText.badge.copyWith(fontSize: 10, color: i <= reached ? PsColors.textPrimary : PsColors.textHint)),
              ],
            ),
            if (i < _steps.length - 1)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.only(bottom: 18),
                  color: i < reached ? PsColors.primary : PsColors.border,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// BUY-C03 Tracking Event Row (Shipment History), newest first.
class PsTrackingEventList extends StatelessWidget {
  const PsTrackingEventList({super.key, required this.events});

  final List<TrackingEvent> events;

  @override
  Widget build(BuildContext context) {
    final rows = events.reversed.toList();
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 24,
                  child: Column(
                    children: [
                      const SizedBox(height: 4),
                      Container(
                        width: i == 0 ? 16 : 11,
                        height: i == 0 ? 16 : 11,
                        decoration: BoxDecoration(
                          color: PsColors.primary,
                          shape: BoxShape.circle,
                          border: i == 0 ? Border.all(color: PsColors.primarySoft, width: 4) : null,
                        ),
                      ),
                      if (i < rows.length - 1) Expanded(child: Container(width: 2, color: PsColors.primary.withAlpha(110))),
                    ],
                  ),
                ),
                const SizedBox(width: PsSpace.sm),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: PsSpace.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(rows[i].title, style: PsText.bodyStrong.copyWith(fontSize: 15)),
                        if (rows[i].description != null) ...[
                          const SizedBox(height: 2),
                          Text(rows[i].description!, style: PsText.caption.copyWith(fontSize: 13)),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          [
                            if (rows[i].occurredAt != null) formatDateTime(rows[i].occurredAt!),
                            if (rows[i].location != null) rows[i].location!,
                          ].join('  ·  '),
                          style: PsText.caption.copyWith(
                            color: i == 0 ? PsColors.textPrimary : PsColors.textMuted,
                            fontWeight: i == 0 ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// BUY-C04 Delivery ETA — only from the stored shipping window; never a
/// fabricated live estimate.
class PsDeliveryEtaCard extends StatelessWidget {
  const PsDeliveryEtaCard({super.key, required this.from, required this.to, this.delivered});

  final DateTime? from;
  final DateTime? to;
  final DateTime? delivered;

  @override
  Widget build(BuildContext context) {
    return PsCard(
      padding: const EdgeInsets.all(PsSpace.lg),
      child: Column(
        children: [
          Text(delivered != null ? 'DELIVERED ON' : 'EXPECTED ARRIVAL WINDOW', style: PsText.overline),
          const SizedBox(height: PsSpace.xs),
          Text(
            delivered != null ? formatShortDate(delivered!) : formatDateRange(from, to),
            style: PsText.display.copyWith(fontSize: 30, fontWeight: FontWeight.w700),
          ),
          if (delivered != null)
            Text(formatTime(delivered!), style: PsText.caption)
          else
            Text('Based on your chosen shipping method', style: PsText.caption),
        ],
      ),
    );
  }
}

/// Copyable identifier row (waybill / tracking number).
class PsCopyValue extends StatelessWidget {
  const PsCopyValue({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(), style: PsText.overline.copyWith(fontSize: 11)),
              const SizedBox(height: 2),
              Text(value, style: PsText.bodyStrong),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Copy $label',
          icon: const Icon(Icons.copy_rounded, size: 20),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: value));
            if (context.mounted) PsToast.success(context, '$label copied');
          },
        ),
      ],
    );
  }
}

/// BUY-C05 Courier Information — only what's permitted: name, vehicle and
/// a call action while the rider is active on this order.
class PsCourierCard extends StatelessWidget {
  const PsCourierCard({super.key, required this.courier, required this.status, this.logisticsName, this.onCall});

  final CourierInfo courier;
  final OrderStatus status;
  final String? logisticsName;
  final VoidCallback? onCall;

  @override
  Widget build(BuildContext context) {
    return PsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: PsColors.primarySoft,
                child: const Icon(Icons.two_wheeler_rounded, color: PsColors.primaryStrong),
              ),
              const SizedBox(width: PsSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(courier.name, style: PsText.heading.copyWith(fontSize: 17)),
                    if (logisticsName != null) Text(logisticsName!, style: PsText.caption),
                  ],
                ),
              ),
              PsStatusBadge.order(status, pill: true),
            ],
          ),
          if (courier.vehicle != null) ...[
            const SizedBox(height: PsSpace.sm),
            Row(
              children: [
                const Icon(Icons.motorcycle_rounded, size: 18, color: PsColors.textMuted),
                const SizedBox(width: 6),
                Text(courier.vehicle!, style: PsText.bodyMuted),
              ],
            ),
          ],
          if (courier.phone != null && onCall != null) ...[
            const SizedBox(height: PsSpace.sm),
            OutlinedButton.icon(
              onPressed: onCall,
              icon: const Icon(Icons.call_rounded, size: 18),
              label: Text('Call rider · ${courier.phone}'),
              style: OutlinedButton.styleFrom(
                foregroundColor: PsColors.primaryStrong,
                minimumSize: const Size.fromHeight(PsSize.minTap),
                side: const BorderSide(color: PsColors.primary),
                shape: RoundedRectangleBorder(borderRadius: PsRadius.button),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// BUY-C06 Delivery Map — live courier location isn't recorded by the
/// logistics backend yet, so this always renders the static fallback with
/// the destination and the last recorded location.
class PsDeliveryMapFallback extends StatelessWidget {
  const PsDeliveryMapFallback({super.key, required this.destination, this.lastLocation});

  final String destination;
  final String? lastLocation;

  @override
  Widget build(BuildContext context) {
    return PsCard(
      color: PsColors.neutralSoft,
      child: Row(
        children: [
          const Icon(Icons.map_outlined, color: PsColors.textMuted, size: 32),
          const SizedBox(width: PsSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Live map isn’t available for this delivery', style: PsText.bodyStrong.copyWith(fontSize: 13.5)),
                const SizedBox(height: 2),
                Text(
                  lastLocation == null ? 'Delivering to $destination' : 'Last update: $lastLocation · Delivering to $destination',
                  style: PsText.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// BUY-C07 Parcel Information — waybill, carrier and parcel identity.
class PsParcelCard extends StatelessWidget {
  const PsParcelCard({super.key, required this.order});

  final OrderDetail order;

  @override
  Widget build(BuildContext context) {
    return PsCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(PsSpace.md),
            child: Row(
              children: [
                Expanded(child: Text('Parcel · ${order.summary.orderNumber}', style: PsText.bodyStrong)),
                PsStatusBadge.order(order.status),
              ],
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(PsSpace.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PsInfoRow(label: 'Carrier', value: order.logisticsName ?? 'Assigned at pickup'),
                PsInfoRow(label: 'Shipping method', value: order.shippingOption ?? '—'),
                if (order.waybillNumber != null) ...[
                  const SizedBox(height: PsSpace.xs),
                  PsCopyValue(label: 'Tracking number', value: order.waybillNumber!),
                ] else
                  Padding(
                    padding: const EdgeInsets.only(top: PsSpace.xs),
                    child: Text('A tracking number appears once the seller hands your parcel to the courier.', style: PsText.caption),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// BUY-C08 Delivery Exception — explains a failed delivery and what the
/// buyer can do next.
class PsDeliveryExceptionCard extends StatelessWidget {
  const PsDeliveryExceptionCard({super.key, required this.order, required this.onContactSupport});

  final OrderDetail order;
  final VoidCallback onContactSupport;

  @override
  Widget build(BuildContext context) {
    final failed = order.events.where((e) => e.status == OrderStatus.deliveryFailed.apiValue).lastOrNull;
    return PsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PsStatusBadge.order(OrderStatus.deliveryFailed, pill: true),
          const SizedBox(height: PsSpace.sm),
          Text('Delivery attempt failed', style: PsText.heading),
          const SizedBox(height: 4),
          Text(
            failed?.description ?? 'Our rider couldn’t complete the delivery.',
            style: PsText.body,
          ),
          if (failed?.occurredAt != null) Text(formatDateTime(failed!.occurredAt!), style: PsText.caption),
          const SizedBox(height: PsSpace.sm),
          Container(
            padding: const EdgeInsets.all(PsSpace.sm),
            decoration: const BoxDecoration(
              color: PsColors.errorSoft,
              border: Border(left: BorderSide(color: PsColors.error, width: 3)),
            ),
            child: Text(
              'We’ll re-attempt delivery. Make sure someone can receive the parcel, or contact support to sort it out.',
              style: PsText.caption.copyWith(color: PsColors.error),
            ),
          ),
          const SizedBox(height: PsSpace.sm),
          OutlinedButton.icon(
            onPressed: onContactSupport,
            icon: const Icon(Icons.support_agent_rounded),
            label: const Text('Contact Support'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(PsSize.minTap)),
          ),
        ],
      ),
    );
  }
}

/// BUY-C12 Refund Status — requested → under review → processing →
/// refunded (or rejected), from the recorded timestamps.
class PsRefundTimeline extends StatelessWidget {
  const PsRefundTimeline({super.key, required this.request});

  final ReturnRequest request;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final stages = <(String, DateTime?, bool)>[
      ('Refund Requested', r.requestedAt, true),
      ('Under Review', r.reviewedAt, r.stage.index >= RefundStage.underReview.index),
      if (r.stage == RefundStage.rejected)
        ('Rejected', r.rejectedAt, true)
      else ...[
        ('Processing', r.processingAt, r.stage.index >= RefundStage.processing.index && r.stage != RefundStage.rejected),
        ('Refunded', r.refundedAt, r.stage == RefundStage.refunded),
      ],
    ];
    final currentIndex = stages.lastIndexWhere((s) => s.$3);

    return Column(
      children: [
        for (var i = 0; i < stages.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 26,
                  child: Column(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: stages[i].$3 ? (i == currentIndex ? PsColors.surface : PsColors.primary) : PsColors.surface,
                          border: Border.all(color: stages[i].$3 ? PsColors.primary : PsColors.border, width: 2),
                        ),
                        child: stages[i].$3 && i != currentIndex
                            ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                            : (i == currentIndex
                                ? Center(child: Container(width: 10, height: 10, decoration: const BoxDecoration(color: PsColors.primary, shape: BoxShape.circle)))
                                : null),
                      ),
                      if (i < stages.length - 1)
                        Expanded(child: Container(width: 2, color: stages[i + 1].$3 ? PsColors.primary : PsColors.border)),
                    ],
                  ),
                ),
                const SizedBox(width: PsSpace.sm),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: PsSpace.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(stages[i].$1, style: PsText.heading.copyWith(fontSize: 16, color: stages[i].$3 ? null : PsColors.textHint)),
                        Text(
                          stages[i].$2 != null ? formatDateTime(stages[i].$2!) : (stages[i].$3 ? '' : 'Pending'),
                          style: PsText.caption,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
