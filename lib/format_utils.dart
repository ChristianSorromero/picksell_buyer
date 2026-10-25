/// 899 -> ₱899, 2450 -> ₱2,450, 1299.5 -> ₱1,299.50
String formatPeso(double value) {
  final isWhole = value == value.truncateToDouble();
  return _peso(value, isWhole ? 0 : 2);
}

/// Always two decimals: 1250 -> ₱1,250.00 (prices, totals, receipts).
String formatPesoFixed(double value) => _peso(value, 2);

String _peso(double value, int decimals) {
  final negative = value < 0;
  final text = value.abs().toStringAsFixed(decimals);
  final parts = text.split('.');
  final whole = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  final body = parts.length > 1 ? '$whole.${parts[1]}' : whole;
  return '${negative ? '-' : ''}₱$body';
}

/// 850 -> 850, 1200 -> 1.2k, 3500 -> 3.5k, 12000 -> 12k
String compactCount(int n) {
  if (n < 1000) return '$n';
  final text = (n / 1000).toStringAsFixed(1);
  return '${text.endsWith('.0') ? text.substring(0, text.length - 2) : text}k';
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// Oct 12, 2023
String formatDate(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';

/// Oct 12
String formatShortDate(DateTime d) => '${_months[d.month - 1]} ${d.day}';

/// 02:15 PM
String formatTime(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '${h.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'}';
}

/// Oct 12, 2023 · 10:30 AM
String formatDateTime(DateTime d) => '${formatDate(d)} · ${formatTime(d)}';

/// Oct 14–16, Oct 30–Nov 2, or a single day.
String formatDateRange(DateTime? from, DateTime? to) {
  if (from == null) return '—';
  if (to == null || (from.year == to.year && from.month == to.month && from.day == to.day)) {
    return formatShortDate(from);
  }
  if (from.month == to.month && from.year == to.year) {
    return '${_months[from.month - 1]} ${from.day}–${to.day}';
  }
  return '${formatShortDate(from)}–${formatShortDate(to)}';
}

/// "2h ago", "Yesterday", "Oct 12"
String formatRelative(DateTime d, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final diff = n.difference(d);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1 && n.day == d.day) return '${diff.inHours}h ago';
  if (diff.inDays < 2) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return d.year == n.year ? formatShortDate(d) : formatDate(d);
}
