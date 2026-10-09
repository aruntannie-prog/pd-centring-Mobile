import '../core/dates.dart';
import '../models/rental.dart';

enum ReminderKind { beforeExpiry, onExpiry, afterExpiry }

class PlannedReminder {
  final int id;
  final String rentalId;
  final ReminderKind kind;

  /// Local wall-clock time the reminder should fire.
  final DateTime fireAt;
  final String title;
  final String body;

  const PlannedReminder({
    required this.id,
    required this.rentalId,
    required this.kind,
    required this.fireAt,
    required this.title,
    required this.body,
  });
}

/// iOS keeps at most 64 pending notifications per app; stay below it.
const int maxScheduledReminders = 60;

/// Works out every reminder that should be pending right now.
///
/// For each open rental: one reminder [leadDays] before expiry, one on the
/// expiry day and one the day after (material not back). Only future times
/// are kept, soonest first, capped at [limit]. Because it is a pure function
/// of the data, the scheduler can simply cancel everything and re-apply this
/// plan whenever data or settings change — no stale or duplicate reminders.
List<PlannedReminder> planReminders(
  List<Rental> rentals, {
  required DateTime now,
  required int leadDays,
  required int hour,
  required int minute,
  String Function(Rental r)? customerNameOf,
  int limit = maxScheduledReminders,
}) {
  final candidates = <PlannedReminder>[];

  for (final r in rentals) {
    if (r.isClosed) continue;
    final who = customerNameOf?.call(r) ?? r.customerName;
    final where = r.site.isEmpty ? '' : ' · ${r.site}';
    final outstanding = r.outstandingItems.length;
    final itemsText = outstanding == 1 ? '1 item' : '$outstanding items';

    DateTime at(DateTime day) =>
        DateTime(day.year, day.month, day.day, hour, minute);

    void add(ReminderKind kind, DateTime day, String title, String body) {
      final fireAt = at(day);
      if (!fireAt.isAfter(now)) return;
      candidates.add(
        PlannedReminder(
          id: 0,
          rentalId: r.id,
          kind: kind,
          fireAt: fireAt,
          title: title,
          body: body,
        ),
      );
    }

    if (leadDays > 0) {
      add(
        ReminderKind.beforeExpiry,
        addDays(r.expiresOn, -leadDays),
        'Expiring in ${leadDays == 1 ? '1 day' : '$leadDays days'}: ${r.dcNumber}',
        '$who$where — $itemsText due back on ${formatDay(r.expiresOn)}',
      );
    }
    add(
      ReminderKind.onExpiry,
      r.expiresOn,
      'Expires today: ${r.dcNumber}',
      '$who$where — $itemsText due back today',
    );
    add(
      ReminderKind.afterExpiry,
      addDays(r.expiresOn, 1),
      'Expired: ${r.dcNumber} not returned',
      '$who$where — $itemsText still out since ${formatDay(r.expiresOn)}',
    );
  }

  candidates.sort((a, b) {
    final t = a.fireAt.compareTo(b.fireAt);
    return t != 0 ? t : a.rentalId.compareTo(b.rentalId);
  });

  final kept = candidates.take(limit).toList();
  return [
    for (var i = 0; i < kept.length; i++)
      PlannedReminder(
        id: i + 1,
        rentalId: kept[i].rentalId,
        kind: kept[i].kind,
        fireAt: kept[i].fireAt,
        title: kept[i].title,
        body: kept[i].body,
      ),
  ];
}
