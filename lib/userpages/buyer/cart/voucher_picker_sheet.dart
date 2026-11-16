import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  void _done() => Navigator.of(context).pop(
    VoucherSheetResult(
      picks: VoucherPicks(stores: _stores, platform: _platform),
    ),
  );

  void _applyCode() {
    final code = _code.text.trim();
    if (code.isEmpty) return;
    Navigator.of(context).pop(
      VoucherSheetResult(
        picks: VoucherPicks(stores: _stores, platform: _platform),
        code: code,
      ),
    );
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
                const SizedBox(height: PsSpace.xs),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: PsTextField(
                        label: 'Have a voucher code?',
                        hint: 'e.g. SAVE50',
                        controller: _code,
                        textCapitalization: TextCapitalization.characters,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _applyCode(),
                        maxLength: 30,
                      ),
                    ),
                    const SizedBox(width: PsSpace.sm),
                    SizedBox(
                      width: 96,
                      child: PsPrimaryButton(label: 'Apply', uppercase: false, onPressed: _applyCode),
                    ),
                  ],
                ),
                if (!v.hasAny)
                  Padding(
                    padding: const EdgeInsets.only(top: PsSpace.lg),
                    child: Text('No store or PickSell vouchers for these items right now.', style: PsText.bodyMuted),
                  ),
                for (final s in stores) ...[
                  const SizedBox(height: PsSpace.lg),
                  Text('${widget.sellerNames[s.sellerId] ?? 'Store'} vouchers'.toUpperCase(), style: PsText.overline),
                  const SizedBox(height: PsSpace.sm),
                  for (final o in s.options)
                    _OptionTile(
                      option: o,
                      platform: false,
                      scope: 'for ${widget.sellerNames[s.sellerId] ?? 'this store'} items only',
                      selected: _stores[s.sellerId] == o.id,
                      onTap: () => setState(() => _stores[s.sellerId] == o.id ? _stores.remove(s.sellerId) : _stores[s.sellerId] = o.id),
                    ),
                ],
                if (v.platform.isNotEmpty) ...[
                  const SizedBox(height: PsSpace.lg),
                  Text('PICKSELL VOUCHERS', style: PsText.overline),
                  const SizedBox(height: PsSpace.sm),
                  for (final o in v.platform)
                    _OptionTile(
                      option: o,
                      platform: true,
                      scope: 'counts your whole order',
                      selected: _platform == o.id,
                      onTap: () => setState(() => _platform = _platform == o.id ? null : o.id),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: PsSpace.md),
          PsPrimaryButton(label: 'Done', uppercase: false, onPressed: _done),
        ],
      ),
    );
  }
}

class _OptionTile extends StatefulWidget {
  const _OptionTile({required this.option, required this.platform, required this.selected, required this.onTap, this.scope});

  final VoucherOption option;
  final bool platform;

  /// What the voucher covers, shown with the reason it can't be used.
  final String? scope;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_OptionTile> createState() => _OptionTileState();
}

class _OptionTileState extends State<_OptionTile> with SingleTickerProviderStateMixin {
  late final _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
  bool _told = false;

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  /// A tap on a voucher that can't be used answers with why: a shake and a note over the cover.
  Future<void> _refuse() async {
    HapticFeedback.mediumImpact();
    setState(() => _told = true);
    _shake.forward(from: 0);
    await Future<void>.delayed(const Duration(milliseconds: 2500));
    if (mounted) setState(() => _told = false);
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.option;
    final platform = widget.platform;
    final selected = widget.selected;
    final scope = widget.scope;
    final onTap = widget.onTap;
    final usable = o.usable;
    final upcoming = o.upcoming && o.startsAt != null;
    // Not usable right now (scheduled for later, min. spend not met, used up): a light grey wash on top.
    final blocked = !usable;
    final accent = platform ? PsColors.primaryStrong : PsColors.primary;
    final recommended = o.recommended && usable && !selected;
    final tile = PsCard(
      onTap: usable || selected ? onTap : (blocked ? _refuse : null),
      borderColor: selected || recommended ? accent : PsColors.border,
      padding: const EdgeInsets.fromLTRB(PsSpace.md, PsSpace.md, PsSpace.sm, PsSpace.sm),
      child: Row(
        children: [
          // Read top to bottom: amount, min. spend (or why not yet), validity, usage.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(o.title.isEmpty ? o.summary : o.title, style: PsText.heading.copyWith(fontSize: 18, color: accent)),
                const SizedBox(height: 2),
                if (blocked && !upcoming)
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: o.problem),
                        if (scope != null) TextSpan(text: ' ($scope)', style: PsText.caption.copyWith(fontSize: 12)),
                      ],
                    ),
                    style: PsText.bodyStrong.copyWith(fontSize: 13, color: PsColors.textSecondary),
                  )
                else
                  Text(o.minSpend > 0 ? 'Min. spend ${formatPeso(o.minSpend)}' : 'No minimum spend', style: PsText.bodyStrong.copyWith(fontSize: 13)),
                if (upcoming)
                  Text(
                    'Starts ${formatShortDate(o.startsAt!)}',
                    style: PsText.caption.copyWith(fontSize: 11.5, fontWeight: FontWeight.w700, color: accent),
                  )
                else if (o.endsAt != null)
                  Text('Valid until ${formatShortDate(o.endsAt!)}, ${o.endsAt!.year}', style: PsText.caption.copyWith(fontSize: 11.5)),
                if (o.usedPercent != null) ...[const SizedBox(height: 8), _UsageBar(percent: o.usedPercent!)],
              ],
            ),
          ),
          const SizedBox(width: PsSpace.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if ((o.usesLeft ?? 0) > 0) _Stamp(count: o.usesLeft!, color: accent),
              const SizedBox(height: PsSpace.xs),
              if (selected)
                Icon(Icons.check_circle_rounded, color: accent)
              else if (usable)
                Text('−${formatPesoFixed(o.discount)}', style: PsText.bodyStrong.copyWith(color: PsColors.success)),
            ],
          ),
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: PsSpace.sm, top: recommended || blocked ? 10 : 0),
      child: AnimatedBuilder(
        animation: _shake,
        builder: (context, child) => Transform.translate(
          offset: Offset(_shake.isAnimating ? 6 * (1 - _shake.value) * (((_shake.value * 6).floor()).isEven ? 1 : -1) : 0, 0),
          child: child,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            tile,
            // The grey cover over a voucher that can't be used; a tap shows the note on it.
            if (blocked)
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: (_told ? Colors.black : const Color(0xFFD1D5DB)).withValues(alpha: _told ? 0.5 : 0.4),
                      borderRadius: PsRadius.card,
                    ),
                    child: AnimatedOpacity(
                      opacity: _told ? 1 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Text("Can't use this voucher", style: PsText.bodyStrong.copyWith(color: Colors.white)),
                    ),
                  ),
                ),
              ),
            if (recommended || blocked)
              Positioned(
                top: -9,
                left: PsSpace.md,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: blocked ? PsColors.textMuted : accent, borderRadius: BorderRadius.circular(99)),
                  child: Text(
                    blocked ? "CAN'T USE" : 'RECOMMENDED',
                    style: PsText.caption.copyWith(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.4),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The buyer's uses left, in a stamp-like circle ("x1").
class _Stamp extends StatelessWidget {
  const _Stamp({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'You can use it $count more ${count == 1 ? 'time' : 'times'}',
      child: Container(
        constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 2),
        ),
        child: ExcludeSemantics(
          child: Text('x$count', style: PsText.bodyStrong.copyWith(fontSize: 13, color: color)),
        ),
      ),
    );
  }
}

/// How much of a voucher's usage limit is taken (same colours as the website).
class _UsageBar extends StatelessWidget {
  const _UsageBar({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    final color = percent >= 100 ? PsColors.textDisabled : (percent >= 80 ? PsColors.warning : PsColors.primary);
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: percent / 100,
              minHeight: 6,
              color: color,
              backgroundColor: PsColors.surfaceMuted,
              semanticsLabel: '$percent% used',
            ),
          ),
        ),
        const SizedBox(width: PsSpace.xs),
        Text('$percent% used', style: PsText.caption.copyWith(fontSize: 11.5)),
      ],
    );
  }
}
