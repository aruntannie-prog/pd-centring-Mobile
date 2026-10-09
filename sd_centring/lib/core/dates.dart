import 'package:intl/intl.dart';

/// Date-only helpers.
///
/// Rental dates (issue date, expiry date, return date) are calendar days, not
/// instants. They are stored as `yyyy-MM-dd` strings so a phone in a different
/// time zone, or a DST change, can never shift a due date by a day.

DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime todayDate() => dayOf(DateTime.now());

DateTime addDays(DateTime d, int days) =>
    DateTime(d.year, d.month, d.day + days);

/// Whole calendar days from [from] to [to]; negative when [to] is earlier.
int daysBetween(DateTime from, DateTime to) {
  final a = DateTime.utc(from.year, from.month, from.day);
  final b = DateTime.utc(to.year, to.month, to.day);
  return b.difference(a).inDays;
}

String toIsoDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Parses `yyyy-MM-dd`. Returns null for anything else.
DateTime? tryParseIsoDay(Object? value) {
  if (value is! String) return null;
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value.trim());
  if (m == null) return null;
  final y = int.parse(m.group(1)!);
  final mo = int.parse(m.group(2)!);
  final d = int.parse(m.group(3)!);
  if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
  final date = DateTime(y, mo, d);
  // Reject overflow such as 2026-02-31 → 3 March.
  if (date.month != mo || date.day != d) return null;
  return date;
}

String formatDay(DateTime d) => DateFormat('d MMM yyyy').format(d);

String formatShortDay(DateTime d) => DateFormat('d MMM').format(d);

String formatWeekday(DateTime d) => DateFormat('EEE, d MMM').format(d);
