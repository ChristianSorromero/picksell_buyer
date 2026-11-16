import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../components/components.dart';
import '../../../models/order.dart';
import '../../../services/order_service.dart';
import 'delivery_problem_page.dart';
import 'delivery_proof_link.dart';
import 'report_problem_page.dart';

/// Track Order (BUY-C01…C08): status header, ETA, courier, map fallback, parcel, one shipment history and the proof-of-delivery link.
class TrackOrderPage extends StatelessWidget {
  const TrackOrderPage({super.key, required this.orderId});

  final int orderId;

  @override
  Widget build(BuildContext context) {
    return PsAppShell(
      topBar: const PsTopBar(title: 'Track Order'),
      body: PsAsyncView<OrderDetail>(
        load: () => OrderService().detail(orderId),
        errorTitle: 'Couldn’t load tracking',
        builder: (context, o, _) {
          final s = o.summary;
          final lastLocation = o.events.reversed.map((e) => e.location).whereType<String>().firstOrNull;
          final hasScans = o.tracking != null && o.tracking!.events.isNotEmpty;
          void support() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReportProblemPage(order: o)));

          return ListView(
            padding: const EdgeInsets.all(PsSpace.gutter),
            children: [
              PsOrderStatusHeader(order: o),
              const SizedBox(height: PsSpace.lg),
              if (o.status == OrderStatus.deliveryFailed) ...[
                PsDeliveryExceptionCard(order: o, onContactSupport: support),
                const SizedBox(height: PsSpace.sm),
              ],
              if (!o.status.isException) ...[
                PsDeliveryEtaCard(from: o.estimatedFrom, to: o.estimatedTo, delivered: o.deliveredAt, status: o.etaStatus, message: o.etaMessage),
                const SizedBox(height: PsSpace.sm),
              ],
              if (o.courier != null) ...[
                PsCourierCard(
                  courier: o.courier!,
                  status: o.status,
                  logisticsName: o.logisticsName,
                  onCall: o.courier!.phone == null
                      ? null
                      : () async {
                          await Clipboard.setData(ClipboardData(text: o.courier!.phone!));
                          if (context.mounted) PsToast.success(context, 'Rider’s number copied');
                        },
                ),
                const SizedBox(height: PsSpace.sm),
              ],
              if (o.status == OrderStatus.outForDelivery && o.shipTo != null) ...[
                PsDeliveryMapFallback(destination: o.shipTo!.fullAddress, lastLocation: lastLocation),
                const SizedBox(height: PsSpace.sm),
              ],
              PsParcelCard(order: o),
              const SizedBox(height: PsSpace.sm),
              PsOrderSummary(
                sellerName: s.seller?.name ?? 'Seller',
                lines: [
                  PsOrderLineRow(
                    name: s.productName,
                    image: s.image,
                    quantity: s.quantity,
                    unitPrice: s.unitPrice,
                    variationLabel: s.variationLabel,
                  ),
                ],
              ),
              const SizedBox(height: PsSpace.lg),
              // One shipment history: Pickrush's parcel scans once the parcel is
              // handed over (the accurate record); the order's own events only
              // before that, so the two never show the same steps twice.
              Text(
                hasScans ? 'Shipment History · ${o.tracking!.trackingNo}' : 'Shipment History',
                style: PsText.heading,
              ),
              const SizedBox(height: PsSpace.sm),
              PsTrackingEventList(
                events: hasScans
                    ? [
                        // Oldest first, as the list expects; the API sends newest first.
                        for (final scan in o.tracking!.events.reversed)
                          TrackingEvent(status: 'scan', title: scan.headline, location: scan.location, occurredAt: scan.at),
                      ]
                    : o.events,
              ),
              if (o.hasProofOfDelivery) ...[
                DeliveryProofLink(orderId: o.id, riderName: o.courier?.name, deliveredAt: o.deliveredAt),
                const SizedBox(height: PsSpace.md),
              ],
              if (o.actions.canReportDelivery) ...[
                PsSecondaryButton.outlined(
                  label: 'Problem with the delivery?',
                  icon: Icons.local_shipping_outlined,
                  expand: true,
                  onPressed: () =>
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => DeliveryProblemPage(order: o))),
                ),
                const SizedBox(height: PsSpace.xs),
              ],
              PsPrimaryButton(
                label: 'Contact Support',
                icon: Icons.support_agent_rounded,
                uppercase: false,
                onPressed: support,
              ),
              const SizedBox(height: PsSpace.lg),
            ],
          );
        },
      ),
    );
  }
}
