import 'package:flutter/material.dart';

import '../../../components/components.dart';
import '../../../format_utils.dart';
import '../../../models/order.dart';
import '../../../services/auth_service.dart';
import '../../../services/order_service.dart';
import '../nav.dart';

/// BUY-A08 Help & Support + BUY-A09 Support Tickets.
class HelpSupportPage extends StatelessWidget {
  const HelpSupportPage({super.key});

  static const _faq = [
    ('How do I track my order?', 'Open Account → My Orders and tap an order. The timeline updates as the seller, sorting center and rider scan your parcel.'),
    ('Can I cancel an order?', 'Yes, until the seller hands the parcel to the courier. Open the order and tap Cancel Order.'),
    ('How do returns work?', 'Within the return window after delivery, open the order and choose Return / Refund. Attach photos so we can review it quickly.'),
    ('Which payment methods are supported?', 'Cash on Delivery for now. GCash, Maya and cards are coming soon.'),
    ('Something is wrong with my order', 'Open the order and tap Report a Problem. Your report goes straight to our support team.'),
  ];

  Future<void> _legal(BuildContext context, String doc) async {
    final r = await AuthService().legal(doc);
    if (!context.mounted) return;
    final body = '${r.data?['body'] ?? ''}'.trim();
    PsBottomSheet.show<void>(
      context,
      title: '${r.data?['title'] ?? (doc == 'terms' ? 'Terms of Service' : 'Privacy Policy')}',
      builder: (_) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(PsSpace.gutter, 0, PsSpace.gutter, PsSpace.lg),
        child: Text(
          !r.success ? r.message : (body.isEmpty ? 'This document hasn’t been published yet.' : body),
          style: PsText.body.copyWith(height: 1.6),
        ),
      ),
    );
  }

  Color _statusColor(String s) => switch (s) {
        'resolved' => PsColors.success,
        'dismissed' => PsColors.textMuted,
        'under_review' => PsColors.info,
        _ => PsColors.warning,
      };

  @override
  Widget build(BuildContext context) {
    return PsAppShell(
      topBar: const PsTopBar(title: 'Help & Support'),
      body: PsAsyncView<List<SupportTicket>>(
        load: OrderService().tickets,
        builder: (context, tickets, _) => ListView(
          padding: const EdgeInsets.all(PsSpace.gutter),
          children: [
            PsCard(
              title: 'My support tickets',
              child: tickets.isEmpty
                  ? Text('No tickets yet. To report an issue, open the order and tap Report a Problem.', style: PsText.bodyMuted)
                  : Column(
                      children: [
                        for (var i = 0; i < tickets.length; i++) ...[
                          if (i > 0) const Divider(),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(tickets[i].subject, style: PsText.bodyStrong),
                            subtitle: Text(
                              [
                                tickets[i].reference,
                                if (tickets[i].createdAt != null) formatDate(tickets[i].createdAt!),
                                if (tickets[i].adminNotes != null) 'Reply: ${tickets[i].adminNotes}',
                              ].join(' · '),
                              style: PsText.caption,
                            ),
                            trailing: PsTag(
                              tickets[i].status.replaceAll('_', ' ').toUpperCase(),
                              color: _statusColor(tickets[i].status),
                              background: _statusColor(tickets[i].status).withAlpha(30),
                            ),
                            onTap: tickets[i].orderId == null ? null : () => openOrder(context, tickets[i].orderId!),
                          ),
                        ],
                      ],
                    ),
            ),
            const SizedBox(height: PsSpace.sm),
            PsCard(
              title: 'Frequently asked questions',
              padding: const EdgeInsets.fromLTRB(PsSpace.md, PsSpace.md, PsSpace.md, PsSpace.xs),
              child: Column(
                children: [
                  for (final (q, a) in _faq)
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      shape: const Border(),
                      title: Text(q, style: PsText.bodyStrong),
                      childrenPadding: const EdgeInsets.only(bottom: PsSpace.sm),
                      children: [Text(a, style: PsText.bodyMuted)],
                    ),
                ],
              ),
            ),
            const SizedBox(height: PsSpace.sm),
            PsCard(
              child: Column(
                children: [
                  PsMenuTile(icon: Icons.description_outlined, label: 'Terms of Service', onTap: () => _legal(context, 'terms')),
                  const Divider(),
                  PsMenuTile(icon: Icons.privacy_tip_outlined, label: 'Privacy Policy', onTap: () => _legal(context, 'privacy')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
