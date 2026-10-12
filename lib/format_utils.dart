/// 899 -> ₱899, 2450 -> ₱2,450, 1299.5 -> ₱1,299.50
String formatPeso(double value) {
  final isWhole = value == value.truncateToDouble();
  final text = isWhole ? value.toInt().toString() : value.toStringAsFixed(2);
  final parts = text.split('.');
  final whole = parts[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (m) => ',',
  );
  return parts.length > 1 ? '₱$whole.${parts[1]}' : '₱$whole';
}

/// 850 -> 850, 1200 -> 1.2k, 3500 -> 3.5k, 12000 -> 12k
String compactCount(int n) {
  if (n < 1000) return '$n';
  final text = (n / 1000).toStringAsFixed(1);
  return '${text.endsWith('.0') ? text.substring(0, text.length - 2) : text}k';
}
