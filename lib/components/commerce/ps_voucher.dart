import 'package:flutter/material.dart';

import '../../core/theme/ps_colors.dart';
import '../../core/theme/ps_tokens.dart';
import '../../core/theme/ps_typography.dart';
import '../../format_utils.dart';
import '../../models/catalog.dart';
import '../shared/forms/ps_text_field.dart';
import '../shared/ps_card.dart';
import '../shared/states/ps_loading_state.dart';

/// One voucher (COM-C14 / BUY-A07): title, min spend, validity, and — when
/// checked against the cart — whether it applies.
class PsVoucherTile extends StatelessWidget {
  const PsVoucherTile({super.key, required this.voucher, this.selected = false, this.onTap, this.status});

  final Voucher voucher;
  final bool selected;
  final VoidCallback? onTap;

  /// Wallet badge, e.g. "USED" / "EXPIRED".
  final String? status;

  @override
  Widget build(BuildContext context) {
    final v = voucher;
    final ineligible = v.eligible == false;
    final enabled = onTap != null && !ineligible && status == null;
    final details = <String>[
      v.minSpend > 0 ? 'Min. Spend ${formatPeso(v.minSpend)}' : 'No Min. Spend',
      if (v.maxDiscount != null && v.type == 'percent') 'Capped at ${formatPeso(v.maxDiscount!)}',
    ];

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                v.title,
                style: PsText.heading.copyWith(fontSize: 19, color: selected ? PsColors.primary : PsColors.textPrimary),
              ),
            ),
            if (v.isLimited) ...[const SizedBox(width: PsSpace.xs), const PsTag('LIMITED')],
            if (status != null) ...[const SizedBox(width: PsSpace.xs), PsTag.muted(status!)],
          ],
        ),
        const SizedBox(height: 4),
        Text(details.join(' · '), style: PsText.bodyStrong.copyWith(fontSize: 13)),
        const SizedBox(height: 2),
        Text(
          [
            'Code ${v.code}',
            if (v.expiresAt != null) 'Valid until ${formatShortDate(v.expiresAt!)}, ${v.expiresAt!.year}',
            if (v.scope == 'store' && v.seller != null) v.seller!.name,
          ].join(' · '),
          style: PsText.caption.copyWith(fontSize: 11.5),
        ),
        if (ineligible && v.minSpend > 0) ...[
          const SizedBox(height: 4),
          Text('Add more items to reach the minimum spend.', style: PsText.caption.copyWith(color: PsColors.warning)),
        ],
      ],
    );

    if (onTap == null) return PsCard(child: body);
    return PsSelectableCard(selected: selected, enabled: enabled, onTap: onTap, child: body);
  }
}

/// COM-C14 Voucher Selector body: code entry + platform/store lists. The
/// caller supplies the data loader and gets the chosen code (or '' to
/// clear) back.
class PsVoucherSheet extends StatefulWidget {
  const PsVoucherSheet({super.key, required this.load, this.selectedCode});

  final Future<({List<Voucher> platform, List<Voucher> store})> Function() load;
  final String? selectedCode;

  @override
  State<PsVoucherSheet> createState() => _PsVoucherSheetState();
}

class _PsVoucherSheetState extends State<PsVoucherSheet> {
  final _code = TextEditingController();
  late Future<({List<Voucher> platform, List<Voucher> store})> _future = widget.load();
  String? _codeError;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _apply() {
    final code = _code.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _codeError = 'Enter a voucher code.');
      return;
    }
    Navigator.of(context).pop(code);
  }

  Widget _section(String title, List<Voucher> vouchers, {String? note}) {
    if (vouchers.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: PsSpace.md),
        Text.rich(
          TextSpan(text: title, children: [if (note != null) TextSpan(text: '  •  $note', style: PsText.caption)]),
          style: PsText.overline,
        ),
        const SizedBox(height: PsSpace.xs),
        for (final v in vouchers) ...[
          PsVoucherTile(
            voucher: v,
            selected: v.code == widget.selectedCode,
            onTap: () => Navigator.of(context).pop(v.code == widget.selectedCode ? '' : v.code),
          ),
          const SizedBox(height: PsSpace.xs),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(PsSpace.gutter, 0, PsSpace.gutter, PsSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _apply(),
            onChanged: (_) {
              if (_codeError != null) setState(() => _codeError = null);
            },
            style: PsText.input,
            decoration: psInputDecoration(
              hint: 'Enter voucher code',
              hasError: _codeError != null,
              suffix: TextButton(onPressed: _apply, child: Text('Apply', style: PsText.link)),
            ),
          ),
          if (_codeError != null) PsFieldError(_codeError!),
          FutureBuilder(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(padding: EdgeInsets.only(top: PsSpace.lg), child: PsLoadingState());
              }
              if (snap.hasError) {
                return Padding(
                  padding: const EdgeInsets.only(top: PsSpace.lg),
                  child: Column(
                    children: [
                      Text('Couldn’t load vouchers.', style: PsText.bodyMuted),
                      TextButton(onPressed: () => setState(() => _future = widget.load()), child: const Text('Try again')),
                    ],
                  ),
                );
              }
              final data = snap.data!;
              final storeName = data.store.isEmpty ? null : data.store.first.seller?.name;
              if (data.platform.isEmpty && data.store.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(top: PsSpace.lg),
                  child: Text('No vouchers are available for these items right now.', style: PsText.bodyMuted, textAlign: TextAlign.center),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _section('PLATFORM VOUCHERS', data.platform),
                  _section('STORE VOUCHERS', data.store, note: storeName),
                  if (widget.selectedCode != null && widget.selectedCode!.isNotEmpty)
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(''),
                      child: Text('Remove voucher', style: PsText.link.copyWith(color: PsColors.textMuted)),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
