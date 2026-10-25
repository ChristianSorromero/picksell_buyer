import 'package:flutter/material.dart';

import '../../../components/components.dart';
import '../../../models/cart.dart';
import '../../../services/checkout_service.dart';

enum _WalletTab { available, used, expired }

/// BUY-A07 Voucher Wallet — available, used and recently expired vouchers.
class VoucherWalletPage extends StatefulWidget {
  const VoucherWalletPage({super.key});

  @override
  State<VoucherWalletPage> createState() => _VoucherWalletPageState();
}

class _VoucherWalletPageState extends State<VoucherWalletPage> {
  _WalletTab _tab = _WalletTab.available;

  @override
  Widget build(BuildContext context) {
    return PsAppShell(
      topBar: PsTopBar(
        title: 'Voucher Wallet',
        bottom: PsSegmentedControl<_WalletTab>(
          selected: _tab,
          onChanged: (t) => setState(() => _tab = t),
          segments: const [
            PsSegment(_WalletTab.available, 'Available'),
            PsSegment(_WalletTab.used, 'Used'),
            PsSegment(_WalletTab.expired, 'Expired'),
          ],
        ),
      ),
      body: PsAsyncView<VoucherWallet>(
        load: CheckoutService().wallet,
        builder: (context, w, _) {
          final list = switch (_tab) {
            _WalletTab.available => w.available,
            _WalletTab.used => w.used,
            _WalletTab.expired => w.expired,
          };
          if (list.isEmpty) {
            return PsEmptyState(
              icon: Icons.confirmation_number_outlined,
              title: switch (_tab) {
                _WalletTab.available => 'No vouchers right now',
                _WalletTab.used => 'No vouchers used yet',
                _WalletTab.expired => 'Nothing expired recently',
              },
              message: _tab == _WalletTab.available ? 'New platform and store vouchers will show up here.' : null,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(PsSpace.gutter),
            itemCount: list.length + (_tab == _WalletTab.available ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(height: PsSpace.sm),
            itemBuilder: (_, i) {
              if (i == list.length) {
                return Text('Pick a voucher in your cart or at checkout to apply it.', textAlign: TextAlign.center, style: PsText.caption);
              }
              return PsVoucherTile(
                voucher: list[i],
                status: switch (_tab) {
                  _WalletTab.used => 'USED',
                  _WalletTab.expired => 'EXPIRED',
                  _ => null,
                },
              );
            },
          );
        },
      ),
    );
  }
}
