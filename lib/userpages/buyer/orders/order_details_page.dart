import 'package:flutter/material.dart';

import '../../../components/components.dart';
import '../../../format_utils.dart';
import '../../../models/cart.dart';
import '../../../models/order.dart';
import '../../../services/order_service.dart';
import '../nav.dart';
import 'order_actions.dart';
import 'refund_status_page.dart';
import 'report_problem_page.dart';
import 'return_request_page.dart';

/// Order Details (BUY-C01 + C14): status, compact progress, address, item,
/// action group, cost breakdown and order information.
class OrderDetailsPage extends StatefulWidget {
  const OrderDetailsPage({super.key, required this.orderId});

  final int orderId;

  @override
  State<OrderDetailsPage> createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends State<OrderDetailsPage> {
  final _orders = OrderService();
  final _view = GlobalKey<PsAsyncViewState<OrderDetail>>();

  Future<void> _push(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    _view.currentState?.reload();
  }

  Future<void> _cancel(OrderDetail o) async {
    List<String> reasons;
    try {
      reasons = (await _orders.options()).cancelReasons;
    } catch (e) {
      if (mounted) PsToast.error(context, errorMessage(e));
      return;
    }
    if (!mounted) return;
    final reason = await PsBottomSheet.options<String>(
      context,
      title: 'Why are you cancelling?',
      options: [for (final r in reasons) PsSheetOption(value: r, label: r)],
    );
    if (reason == null || !mounted) return;
    final ok = await PsDialog.confirm(
      context,
      title: 'Cancel this order?',
      message: '${o.summary.productName} (${o.summary.orderNumber}) will be cancelled. This can’t be undone.',
      confirmLabel: 'Cancel order',
      cancelLabel: 'Keep order',
      destructive: true,
    );
    if (!ok) return;
    try {
      final updated = await _orders.cancel(o.id, reason);
      _view.currentState?.replace(updated);
      if (mounted) PsToast.success(context, 'Order cancelled');
    } catch (e) {
      if (mounted) PsDialog.error(context, title: 'Couldn’t cancel', message: errorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PsAppShell(
      topBar: PsTopBar(
        title: 'Order Details',
        actions: [
          Builder(
            builder: (context) => PsIconButton(
              icon: Icons.help_outline_rounded,
              tooltip: 'Get help with this order',
              onPressed: () {
                final o = _view.currentState?.data;
                if (o != null) _push(ReportProblemPage(order: o));
              },
            ),
          ),
        ],
      ),
      body: PsAsyncView<OrderDetail>(
        key: _view,
        load: () => _orders.detail(widget.orderId),
        errorTitle: 'Couldn’t load this order',
        builder: (context, o, reload) {
          final s = o.summary;
          return ListView(
            padding: const EdgeInsets.all(PsSpace.gutter),
            children: [
              PsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.circle, size: 10, color: o.status.tone.foreground),
                        const SizedBox(width: 8),
                        Expanded(child: Text(o.status.buyerLabel, style: PsText.heading.copyWith(fontSize: 22, color: o.status.tone.foreground))),
                      ],
                    ),
                    if (o.status.isException && o.cancelReason != null) ...[
                      const SizedBox(height: 4),
                      Text('Reason: ${o.cancelReason}', style: PsText.caption),
                    ],
                    if (!o.status.isException) ...[
                      const SizedBox(height: PsSpace.md),
                      PsOrderProgressBar(status: o.status),
                    ],
                  ],
                ),
              ),
              if (o.status == OrderStatus.deliveryFailed) ...[
                const SizedBox(height: PsSpace.sm),
                PsDeliveryExceptionCard(order: o, onContactSupport: () => _push(ReportProblemPage(order: o))),
              ],
              const SizedBox(height: PsSpace.sm),
              if (o.shipTo != null)
                PsAddressCard(
                  title: 'Shipping Address',
                  name: o.shipTo!.recipientName,
                  phone: o.shipTo!.displayPhone,
                  address: o.shipTo!.fullAddress,
                ),
              const SizedBox(height: PsSpace.sm),
              PsOrderSummary(
                sellerName: s.seller?.name ?? 'Seller',
                verified: s.seller?.verified ?? false,
                lines: [
                  PsOrderLineRow(
                    name: s.productName,
                    image: s.image,
                    quantity: s.quantity,
                    unitPrice: s.unitPrice,
                    variationLabel: s.variationLabel,
                    onTap: s.productId == null ? null : () => openProduct(context, s.productId!),
                  ),
                ],
              ),
              const SizedBox(height: PsSpace.sm),
              PsOrderActionGroup(
                order: o,
                onRate: () async {
                  final updated = await rateOrder(context, o.id, s.productName);
                  if (updated != null) _view.currentState?.replace(updated);
                },
                onTrack: () => openTracking(context, o.id).then((_) => reload()),
                onBuyAgain: () => buyAgain(context, o.id),
                onCancel: () => _cancel(o),
                onReturn: () => _push(ReturnRequestPage(order: o)),
                onRefundStatus: () => _push(RefundStatusPage(order: o)),
                onReport: () => _push(ReportProblemPage(order: o)),
              ),
              if (o.feedback != null || s.rating != null) ...[
                const SizedBox(height: PsSpace.sm),
                PsCard(
                  title: 'Your review',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PsRatingStars(rating: (s.rating ?? 0).toDouble(), size: 18),
                      if (o.feedback != null) ...[const SizedBox(height: 6), Text(o.feedback!, style: PsText.body)],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: PsSpace.sm),
              PsCostBreakdown(
                title: 'Payment Details',
                voucherCode: o.voucherCode,
                totals: _totals(o),
              ),
              const SizedBox(height: PsSpace.sm),
              PsCard(
                title: 'Order Information',
                child: Column(
                  children: [
                    PsInfoRow(label: 'Order ID', value: s.orderNumber, emphasize: true),
                    if (s.createdAt != null) PsInfoRow(label: 'Order Time', value: formatDateTime(s.createdAt!)),
                    PsInfoRow(label: 'Payment Method', value: o.paymentMethod ?? 'Cash on Delivery'),
                    if (o.shippingOption != null) PsInfoRow(label: 'Shipping', value: o.shippingOption!),
                    if (o.waybillNumber != null) PsInfoRow(label: 'Tracking No.', value: o.waybillNumber!),
                    if (o.deliveredAt != null) PsInfoRow(label: 'Delivered', value: formatDateTime(o.deliveredAt!)),
                  ],
                ),
              ),
              const SizedBox(height: PsSpace.lg),
            ],
          );
        },
      ),
    );
  }
}

CostTotals _totals(OrderDetail o) => CostTotals(
      merchandiseSubtotal: o.subtotal,
      shippingTotal: o.shippingFee,
      discountTotal: o.discount,
      serviceFee: o.serviceFee,
      total: o.summary.total,
    );
