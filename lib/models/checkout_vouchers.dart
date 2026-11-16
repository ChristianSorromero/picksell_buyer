import 'json.dart';

/// One store or PickSell voucher on offer at checkout (website: checkout voucher picker).
class VoucherOption {
  const VoucherOption({
    required this.id,
    required this.code,
    required this.title,
    required this.summary,
    required this.type,
    this.discount = 0,
    this.problem,
    this.endsAt,
    this.usedPercent,
    this.usesLeft,
    this.recommended = false,
    this.minSpend = 0,
    this.startsAt,
    this.upcoming = false,
  });

  final int id;
  final String code;
  final String title;

  /// "₱50 off · min. spend ₱500", "10% off up to ₱100", "Free shipping".
  final String summary;

  /// fixed, percent or free_shipping.
  final String type;

  /// What it takes off this checkout.
  final double discount;

  /// Why it can't be used right now ("Spend ₱200.00 more…"); null when it can.
  final String? problem;
  final DateTime? endsAt;

  /// How much of its usage limit is taken, 0–100; null when it has no limit.
  final int? usedPercent;

  /// How many more times this buyer may use it (the "x1" stamp).
  final int? usesLeft;

  /// The best usable saving on offer, flagged for the buyer.
  final bool recommended;
  final double minSpend;

  /// Scheduled and not started yet: shown ahead as a teaser, not usable.
  final DateTime? startsAt;
  final bool upcoming;

  bool get usable => problem == null;

  factory VoucherOption.fromJson(Json j) => VoucherOption(
        id: toInt(j['id']),
        code: j['code'] as String? ?? '',
        title: j['title'] as String? ?? '',
        summary: j['summary'] as String? ?? '',
        type: j['type'] as String? ?? 'fixed',
        discount: toDouble(j['discount']),
        problem: toStr(j['problem']),
        endsAt: toDate(j['ends_at']),
        usedPercent: j['used_percent'] == null ? null : toInt(j['used_percent']),
        usesLeft: j['uses_left'] == null ? null : toInt(j['uses_left']),
        recommended: j['recommended'] == true,
        minSpend: toDouble(j['min_spend']),
        startsAt: toDate(j['starts_at']),
        upcoming: j['upcoming'] == true,
      );
}

/// A store's vouchers (one can be picked per store; the store pays for it).
class StoreVoucherOptions {
  const StoreVoucherOptions({required this.sellerId, this.options = const []});

  final int sellerId;
  final List<VoucherOption> options;

  factory StoreVoucherOptions.fromJson(Json j) =>
      StoreVoucherOptions(sellerId: toInt(j['seller_id']), options: listOf(j['options'], VoucherOption.fromJson));
}

/// The quote's `vouchers`: what's on offer, what's picked and what it saves.
class CheckoutVouchers {
  const CheckoutVouchers({
    this.stores = const [],
    this.platform = const [],
    this.pickedStores = const {},
    this.pickedPlatform,
    this.storeSavings = const {},
    this.platformSaving = 0,
    this.total = 0,
    this.error,
  });

  final List<StoreVoucherOptions> stores;

  /// PickSell vouchers (one per checkout; PickSell pays for it).
  final List<VoucherOption> platform;

  /// seller id → picked store voucher id.
  final Map<int, int> pickedStores;
  final int? pickedPlatform;

  /// seller id → what that store's voucher saves.
  final Map<int, double> storeSavings;
  final double platformSaving;
  final double total;

  /// Why a picked or typed voucher didn't apply.
  final String? error;

  double get storeSaving => storeSavings.values.fold(0, (s, v) => s + v);
  bool get hasAny => platform.isNotEmpty || stores.any((s) => s.options.isNotEmpty);
  int get pickedCount => pickedStores.length + (pickedPlatform == null ? 0 : 1);

  /// The picked vouchers' codes, for the checkout row ("SAVE100 · PICK10").
  List<String> get pickedCodes => [
        for (final s in stores)
          if (pickedStores[s.sellerId] != null) ...s.options.where((o) => o.id == pickedStores[s.sellerId]).map((o) => o.code),
        if (pickedPlatform != null) ...platform.where((o) => o.id == pickedPlatform).map((o) => o.code),
      ];

  factory CheckoutVouchers.fromJson(Json j) {
    final picked = mapOrNull(j['picked']) ?? const {};
    Map<int, T> byId<T>(Object? v, T Function(Object?) read) => {
          for (final e in (mapOrNull(v) ?? const {}).entries)
            if (int.tryParse(e.key) != null) int.parse(e.key): read(e.value),
        };
    return CheckoutVouchers(
      stores: listOf(j['stores'], StoreVoucherOptions.fromJson),
      platform: listOf(j['platform'], VoucherOption.fromJson),
      pickedStores: byId(picked['stores'], (v) => toInt(v)),
      pickedPlatform: picked['platform'] == null ? null : toInt(picked['platform']),
      storeSavings: byId(j['store_savings'], (v) => toDouble(v)),
      platformSaving: toDouble(j['platform_saving']),
      total: toDouble(j['total']),
      error: toStr(j['error']),
    );
  }
}
