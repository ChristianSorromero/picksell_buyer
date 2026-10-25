import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../components/components.dart';
import '../../../format_utils.dart';
import '../../../models/order.dart';
import '../../../services/order_service.dart';
import 'report_problem_page.dart';

/// Track Order (BUY-C01…C08): status header, Pick Thread with real
/// timestamps, ETA, courier, map fallback, parcel and shipment history.
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
          final timestamps = <OrderStatus, String>{
            for (final status in OrderStatus.values)
              if (o.reachedAt(status) != null) status: formatDateTime(o.reachedAt(status)!),
          };
          final lastLocation = o.events.reversed.map((e) => e.location).whereType<String>().firstOrNull;
          void support() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReportProblemPage(order: o)));

          return ListView(
            padding: const EdgeInsets.all(PsSpace.gutter),
            children: [
              PsOrderStatusHeader(order: o),
              const SizedBox(height: PsSpace.lg),
              PsPickThread.forOrder(current: o.status, timestamps: timestamps),
              const SizedBox(height: PsSpace.md),
              if (o.status == OrderStatus.deliveryFailed) ...[
                PsDeliveryExceptionCard(order: o, onContactSupport: support),
                const SizedBox(height: PsSpace.sm),
              ],
              if (!o.status.isException) ...[
                PsDeliveryEtaCard(from: o.estimatedFrom, to: o.estimatedTo, delivered: o.deliveredAt),
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
                lines: [PsOrderLineRow(name: s.productName, image: s.image, quantity: s.quantity, unitPrice: s.unitPrice, variationLabel: s.variationLabel)],
              ),
              const SizedBox(height: PsSpace.lg),
              Text('Shipment History', style: PsText.heading),
              const SizedBox(height: PsSpace.sm),
              PsTrackingEventList(events: o.events),
              PsPrimaryButton(label: 'Contact Support', icon: Icons.support_agent_rounded, uppercase: false, onPressed: support),
              const SizedBox(height: PsSpace.lg),
            ],
          );
        },
      ),
    );
  }
}
