/// Quantities can be fractional (e.g. running feet), so comparisons use a
/// small tolerance instead of `==` to avoid floating point surprises.
const double qtyEpsilon = 1e-6;

bool qtyIsZero(double q) => q.abs() < qtyEpsilon;

/// Rounds to 2 decimals so repeated additions never drift.
double roundQty(double q) => (q * 100).roundToDouble() / 100;

String formatQty(double q) {
  final r = roundQty(q);
  if (r == r.truncateToDouble()) return r.toInt().toString();
  return r.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '');
}

/// Parses user input; returns null when it is not a positive number.
double? parsePositiveQty(String text) {
  final v = double.tryParse(text.trim());
  if (v == null || v.isNaN || v.isInfinite || v <= 0) return null;
  return roundQty(v);
}
