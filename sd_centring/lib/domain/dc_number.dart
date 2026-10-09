import '../models/rental.dart';

/// Suggests the next DC number: one above the highest existing number with
/// the same [prefix], or [start] when there are none.
///
/// Computed from data already on the device so it also works offline. The
/// number stays editable and uniqueness is checked again on save.
String nextDcNumber(
  Iterable<Rental> rentals, {
  required String prefix,
  required int start,
}) {
  var max = start - 1;
  for (final r in rentals) {
    final n = dcSequence(r.dcNumber, prefix);
    if (n != null && n > max) max = n;
  }
  return '$prefix${max + 1}';
}

int? dcSequence(String dcNumber, String prefix) {
  final s = dcNumber.trim();
  if (!s.toUpperCase().startsWith(prefix.toUpperCase())) return null;
  return int.tryParse(s.substring(prefix.length));
}

bool isDcNumberTaken(
  Iterable<Rental> rentals,
  String dcNumber, {
  String? exceptId,
}) {
  final wanted = dcNumber.trim().toUpperCase();
  return rentals.any(
    (r) => r.id != exceptId && r.dcNumber.trim().toUpperCase() == wanted,
  );
}
