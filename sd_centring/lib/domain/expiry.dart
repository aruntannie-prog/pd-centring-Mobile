import '../core/dates.dart';
import '../models/rental.dart';

enum ExpiryStatus {
  /// Past the expiry date with material still out.
  expired,

  /// Expires today.
  dueToday,

  /// Expires within the "expiring soon" window.
  dueSoon,

  /// Out on rent, expiry comfortably ahead.
  active,

  /// All material returned.
  closed,
}

class ExpiryInfo {
  final ExpiryStatus status;

  /// Days from today until expiry. Negative once expired.
  final int daysLeft;

  const ExpiryInfo(this.status, this.daysLeft);

  bool get isOpen => status != ExpiryStatus.closed;

  /// Short human label, e.g. "3 days left", "Expires today", "5 days overdue".
  String get label {
    switch (status) {
      case ExpiryStatus.closed:
        return 'Returned';
      case ExpiryStatus.expired:
        final d = -daysLeft;
        return d == 1 ? '1 day overdue' : '$d days overdue';
      case ExpiryStatus.dueToday:
        return 'Expires today';
      case ExpiryStatus.dueSoon:
      case ExpiryStatus.active:
        return daysLeft == 1 ? '1 day left' : '$daysLeft days left';
    }
  }
}

/// Pure function: the expiry state of [rental] as seen on [today].
ExpiryInfo expiryOf(
  Rental rental, {
  required DateTime today,
  required int soonDays,
}) {
  final left = daysBetween(today, rental.expiresOn);
  if (rental.isClosed) return ExpiryInfo(ExpiryStatus.closed, left);
  if (left < 0) return ExpiryInfo(ExpiryStatus.expired, left);
  if (left == 0) return ExpiryInfo(ExpiryStatus.dueToday, left);
  if (left <= soonDays) return ExpiryInfo(ExpiryStatus.dueSoon, left);
  return ExpiryInfo(ExpiryStatus.active, left);
}

/// Sort order for "what needs attention first": most overdue at the top,
/// then soonest expiry, closed last.
int compareByUrgency(Rental a, Rental b) {
  if (a.isClosed != b.isClosed) return a.isClosed ? 1 : -1;
  final byDate = a.expiresOn.compareTo(b.expiresOn);
  if (byDate != 0) return byDate;
  return a.dcNumber.compareTo(b.dcNumber);
}
