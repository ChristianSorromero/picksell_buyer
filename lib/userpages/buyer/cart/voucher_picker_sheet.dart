import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../components/components.dart';
import '../../../format_utils.dart';
import '../../../models/checkout_vouchers.dart';
import '../../../services/checkout_service.dart';

/// What the buyer chose in a voucher sheet: the picks to quote with, or a typed code.
class VoucherSheetResult {
  const VoucherSheetResult({required this.picks, this.code, this.codeFor});

  final VoucherPicks picks;

  /// A typed code: the quote picks the voucher it is among [codeFor]'s.
  final String? code;

  /// 'platform' or the seller id the code was typed for.
  final String? codeFor;
}

/// The website checkout's voucher picker, for one store or for PickSell.
///
/// A store's sheet ([sellerId]) lists its store vouchers (the store pays) and
/// its items' product vouchers: one of them per store, never both kinds. The
/// PickSell sheet ([sellerId] null) lists PickSell vouchers (PickSell pays),
/// one per checkout. Either takes a typed code. Savings shown are the
/// server's; the quote checks the picks again.
class VoucherPickerSheet extends StatefulWidget {
  const VoucherPickerSheet({super.key, required this.vouchers, required this.picks, this.sellerId, this.sellerName});

  final CheckoutVouchers vouchers;
  final VoucherPicks picks;

  /// The store whose vouchers these are; null for PickSell vouchers.
  final int? sellerId;
  final String? sellerName;

  @override
  State<VoucherPickerSheet> createState() => _VoucherPickerSheetState();
}

class _VoucherPickerSheetState extends State<VoucherPickerSheet> {
  late VoucherPicks _picks = widget.picks;
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _done() => Navigator.of(context).pop(VoucherSheetResult(picks: _picks));

  void _applyCode() {
    final code = _code.text.trim();
    if (code.isEmpty) return;
    Navigator.of(context).pop(VoucherSheetResult(picks: _picks, code: code, codeFor: widget.sellerId?.toString() ?? 'platform'));
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.vouchers;
    final sellerId = widget.sellerId;
    final store = sellerId == null ? null : v.storeOf(sellerId);
    final storeName = widget.sellerName ?? 'this store';
    final empty = store == null ? v.platform.isEmpty : store.isEmpty;
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
                        label: store == null ? 'Have a PickSell voucher code?' : 'Have a voucher code?',
                        hint: store == null ? 'e.g. SAVE50' : 'Store or product code',
                        controller: _code,
                        // Product codes are case-sensitive, so a store's field keeps what is typed.
                        textCapitalization: store == null ? TextCapitalization.characters : TextCapitalization.none,
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
                if (empty)
                  Padding(
                    padding: const EdgeInsets.only(top: PsSpace.lg),
                    child: Text(store == null ? 'No PickSell vouchers right now.' : 'No vouchers from $storeName for these items.', style: PsText.bodyMuted),
                  ),
                if (store != null && sellerId != null && !store.isEmpty) ...[
                  Text('One voucher per store: a store voucher or a product voucher.', style: PsText.caption),
                  if (store.options.isNotEmpty) ...[
                    const SizedBox(height: PsSpace.lg),
                    Text('STORE VOUCHERS', style: PsText.overline),
                    const SizedBox(height: PsSpace.sm),
                    for (final o in store.options)
                      _OptionTile(
                        option: o,
                        platform: false,
                        scope: 'for $storeName items only',
                        selected: _picks.stores[sellerId] == o.id,
                        onTap: () => setState(() => _picks = _picks.withStore(sellerId, storeVoucher: _picks.stores[sellerId] == o.id ? null : o.id)),
                      ),
                  ],
                  if (store.productOptions.isNotEmpty) ...[
                    const SizedBox(height: PsSpace.lg),
                    Text('PRODUCT VOUCHERS', style: PsText.overline),
                    const SizedBox(height: PsSpace.sm),
                    for (final o in store.productOptions)
                      _ProductTile(
                        option: o,
                        selected: _picks.products[sellerId] == o.code,
                        onTap: () => setState(() => _picks = _picks.withStore(sellerId, productCode: _picks.products[sellerId] == o.code ? null : o.code)),
                      ),
                  ],
                ],
                if (store == null && v.platform.isNotEmpty) ...[
                  const SizedBox(height: PsSpace.lg),
                  for (final o in v.platform)
                    _OptionTile(
                      option: o,
                      platform: true,
                      scope: 'counts your whole order',
                      selected: _picks.platform == o.id,
                      onTap: () => setState(() => _picks = _picks.withPlatform(_picks.platform == o.id ? null : o.id)),
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

/// A product voucher of one of the store's items: its % off, code and item.
class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.option, required this.selected, required this.onTap});

  final ProductVoucherOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final o = option;
    final percent = o.percent == o.percent.roundToDouble() ? o.percent.toStringAsFixed(0) : o.percent.toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: PsSpace.sm),
      child: PsCard(
        onTap: onTap,
        borderColor: selected ? PsColors.primary : PsColors.border,
        padding: const EdgeInsets.fromLTRB(PsSpace.md, PsSpace.md, PsSpace.sm, PsSpace.md),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$percent% off', style: PsText.heading.copyWith(fontSize: 18, color: PsColors.primary)),
                  const SizedBox(height: 2),
                  Text('Code ${o.code}', style: PsText.bodyStrong.copyWith(fontSize: 13)),
                  Text('For ${o.product}', style: PsText.caption.copyWith(fontSize: 11.5), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: PsSpace.sm),
            if (selected)
              Icon(Icons.check_circle_rounded, color: PsColors.primary)
            else
              Text('−${formatPesoFixed(o.discount)}', style: PsText.bodyStrong.copyWith(color: PsColors.success)),
          ],
        ),
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
