import 'package:flutter/material.dart';

import '../../../components/components.dart';
import '../../../format_utils.dart';
import '../../../models/checkout_vouchers.dart';
import '../../../services/checkout_service.dart';

/// What the buyer chose in the voucher sheet: the picks to quote with, or a typed code.
class VoucherSheetResult {
  const VoucherSheetResult({required this.picks, this.code});

  final VoucherPicks picks;

  /// A typed code: the quote picks the store or PickSell voucher it belongs to.
  final String? code;
}

/// The website checkout's voucher picker: one voucher per store (the store
/// pays for it) and one PickSell voucher (PickSell pays), or a typed code.
/// Savings shown are the server's; the quote checks the picks again.
class VoucherPickerSheet extends StatefulWidget {
  const VoucherPickerSheet({super.key, required this.vouchers, required this.sellerNames, required this.picks});

  final CheckoutVouchers vouchers;

  /// seller id → store name, for each store's heading.
  final Map<int, String> sellerNames;
  final VoucherPicks picks;

  @override
  State<VoucherPickerSheet> createState() => _VoucherPickerSheetState();
}

class _VoucherPickerSheetState extends State<VoucherPickerSheet> {
  late final Map<int, int> _stores = {...widget.picks.stores};
  late int? _platform = widget.picks.platform;
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _done() => Navigator.of(context).pop(VoucherSheetResult(picks: VoucherPicks(stores: _stores, platform: _platform)));

  void _applyCode() {
    final code = _code.text.trim();
    if (code.isEmpty) return;
    Navigator.of(context).pop(VoucherSheetResult(picks: VoucherPicks(stores: _stores, platform: _platform), code: code));
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.vouchers;
    final stores = v.stores.where((s) => s.options.isNotEmpty).toList();
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                Text('Have a voucher code?', style: PsText.bodyStrong),
                const SizedBox(height: PsSpace.xs),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: PsTextField(
                        label: 'Voucher code',
                        hint: 'e.g. SAVE50',
                        controller: _code,
                        textCapitalization: TextCapitalization.characters,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _applyCode(),
                        maxLength: 30,
                      ),
                    ),
                    const SizedBox(width: PsSpace.xs),
                    Padding(
                      padding: const EdgeInsets.only(top: 22),
                      child: SizedBox(
                        width: 96,
                        child: PsPrimaryButton(label: 'Apply', uppercase: false, onPressed: _applyCode),
                      ),
                    ),
                  ],
                ),
                if (!v.hasAny)
                  Padding(
                    padding: const EdgeInsets.only(top: PsSpace.md),
                    child: Text('No store or PickSell vouchers for these items right now.', style: PsText.bodyMuted),
                  ),
                for (final s in stores) ...[
                  const SizedBox(height: PsSpace.md),
                  Text('${widget.sellerNames[s.sellerId] ?? 'Store'} vouchers'.toUpperCase(), style: PsText.overline),
                  const SizedBox(height: PsSpace.xs),
                  for (final o in s.options)
                    _OptionTile(
                      option: o,
                      platform: false,
                      selected: _stores[s.sellerId] == o.id,
                      onTap: () => setState(() => _stores[s.sellerId] == o.id ? _stores.remove(s.sellerId) : _stores[s.sellerId] = o.id),
                    ),
                ],
                if (v.platform.isNotEmpty) ...[
                  const SizedBox(height: PsSpace.md),
                  Text('PICKSELL VOUCHERS', style: PsText.overline),
                  const SizedBox(height: PsSpace.xs),
                  for (final o in v.platform)
                    _OptionTile(
                      option: o,
                      platform: true,
                      selected: _platform == o.id,
                      onTap: () => setState(() => _platform = _platform == o.id ? null : o.id),
                    ),
                ],
                const SizedBox(height: PsSpace.sm),
              ],
            ),
          ),
          const SizedBox(height: PsSpace.sm),
          PsPrimaryButton(label: 'Done', uppercase: false, onPressed: _done),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({required this.option, required this.platform, required this.selected, required this.onTap});

  final VoucherOption option;
  final bool platform;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final o = option;
    final usable = o.usable;
    final accent = platform ? PsColors.primaryStrong : PsColors.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: PsSpace.xs),
      child: Opacity(
        opacity: usable ? 1 : 0.55,
        child: PsCard(
          onTap: usable || selected ? onTap : null,
          borderColor: selected ? accent : PsColors.border,
          padding: const EdgeInsets.all(PsSpace.sm),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                constraints: const BoxConstraints(minWidth: 74),
                decoration: BoxDecoration(color: platform ? PsColors.primarySoft : PsColors.surfaceMuted, borderRadius: BorderRadius.circular(8)),
                child: Text(o.code, textAlign: TextAlign.center, style: PsText.bodyStrong.copyWith(fontSize: 12, color: accent)),
              ),
              const SizedBox(width: PsSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(o.title.isEmpty ? o.summary : o.title, style: PsText.bodyStrong),
                    const SizedBox(height: 2),
                    Text(
                      o.problem ?? [o.summary, if (o.endsAt != null) 'until ${formatShortDate(o.endsAt!)}'].join(' · '),
                      style: PsText.caption.copyWith(color: usable ? null : PsColors.error),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: PsSpace.xs),
              if (selected)
                Icon(Icons.check_circle_rounded, color: accent)
              else if (usable)
                Text('−${formatPesoFixed(o.discount)}', style: PsText.bodyStrong.copyWith(color: accent)),
            ],
          ),
        ),
      ),
    );
  }
}
