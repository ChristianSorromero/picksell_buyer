/// Tolerant JSON readers: Laravel sends decimals as int or double and
/// dates as ISO-8601 strings.
typedef Json = Map<String, dynamic>;

double toDouble(Object? v, [double fallback = 0]) =>
    v is num ? v.toDouble() : double.tryParse('$v') ?? fallback;

double? toDoubleOrNull(Object? v) => v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));

int toInt(Object? v, [int fallback = 0]) => v is num ? v.toInt() : int.tryParse('$v') ?? fallback;

DateTime? toDate(Object? v) => v is String && v.isNotEmpty ? DateTime.tryParse(v)?.toLocal() : null;

String? toStr(Object? v) => v == null ? null : '$v';

List<T> listOf<T>(Object? v, T Function(Json) parse) =>
    v is List ? v.whereType<Map>().map((e) => parse(e.cast<String, dynamic>())).toList() : <T>[];

Json? mapOrNull(Object? v) => v is Map ? v.cast<String, dynamic>() : null;
