import 'package:intl/intl.dart';

final _whole = NumberFormat('#,##0', 'en_US');
final _cents = NumberFormat('#,##0.00', 'en_US');

/// "₱85,000" for whole amounts, "₱85,000.50" otherwise.
String formatPeso(double amount) {
  final value = amount.abs();
  final isWhole = (value - value.roundToDouble()).abs() < 0.005;
  final text = isWhole ? _whole.format(value.round()) : _cents.format(value);
  return '${amount < 0 ? '-' : ''}₱$text';
}

/// Always two decimals: "₱450.00".
String formatPesoCents(double amount) {
  final text = _cents.format(amount.abs());
  return '${amount < 0 ? '-' : ''}₱$text';
}

/// Signed delta: "+₱5,000" / "-₱2,100".
String formatPesoDelta(double delta) {
  final sign = delta < 0 ? '-' : '+';
  return '$sign${formatPeso(delta.abs())}';
}

/// "+12%" / "-5%".
String formatPercentChange(double percent) {
  final rounded = percent.round();
  return '${rounded >= 0 ? '+' : ''}$rounded%';
}
