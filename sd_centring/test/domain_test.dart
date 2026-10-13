import 'package:flutter_test/flutter_test.dart';
import 'package:sd_centring/core/dates.dart';
import 'package:sd_centring/core/quantity.dart';
import 'package:sd_centring/domain/dc_number.dart';
import 'package:sd_centring/domain/expiry.dart';
import 'package:sd_centring/domain/reminders.dart';
import 'package:sd_centring/models/customer.dart';
import 'package:sd_centring/models/rental.dart';

Rental rental({
  String id = 'r1',
  String dc = 'SD-1001',
  required DateTime issued,
  required DateTime expires,
  List<RentalItem> items = const [RentalItem(id: 'a', name: 'Props', qty: 40)],
  List<ReturnEntry> returns = const [],
}) => Rental(
  id: id,
  dcNumber: dc,
  customerId: 'c1',
  customerName: 'Murugan',
  site: 'Tambaram',
  issuedOn: issued,
  expiresOn: expires,
  items: items,
  returns: returns,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  final today = DateTime(2026, 10, 9);

  group('dates', () {
    test('iso day round trip and validation', () {
      expect(toIsoDay(DateTime(2026, 3, 7)), '2026-03-07');
      expect(tryParseIsoDay('2026-03-07'), DateTime(2026, 3, 7));
      expect(tryParseIsoDay('2026-02-31'), isNull);
      expect(tryParseIsoDay('07-03-2026'), isNull);
      expect(tryParseIsoDay(42), isNull);
    });

    test('daysBetween counts calendar days', () {
      expect(
        daysBetween(DateTime(2026, 10, 9, 23, 59), DateTime(2026, 10, 10)),
        1,
      );
      expect(daysBetween(DateTime(2026, 10, 9), DateTime(2026, 10, 5)), -4);
      expect(daysBetween(DateTime(2026, 2, 27), DateTime(2026, 3, 2)), 3);
    });
  });

  group('quantity', () {
    test('formats and parses', () {
      expect(formatQty(40), '40');
      expect(formatQty(12.5), '12.5');
      expect(formatQty(0.1 + 0.2), '0.3');
      expect(parsePositiveQty('15'), 15);
      expect(parsePositiveQty('0'), isNull);
      expect(parsePositiveQty('-3'), isNull);
      expect(parsePositiveQty('abc'), isNull);
    });
  });

  group('rental returns', () {
    test('partial returns reduce outstanding; full return closes', () {
      var r = rental(
        issued: DateTime(2026, 10, 1),
        expires: DateTime(2026, 10, 31),
      );
      expect(r.isClosed, isFalse);
      r = r.copyWith(
        returns: [
          ReturnEntry(
            id: 'x1',
            itemId: 'a',
            qty: 15,
            date: DateTime(2026, 10, 5),
          ),
        ],
      );
      expect(r.outstandingQty(r.items.first), 25);
      expect(r.isClosed, isFalse);
      r = r.copyWith(
        returns: [
          ...r.returns,
          ReturnEntry(
            id: 'x2',
            itemId: 'a',
            qty: 25,
            date: DateTime(2026, 10, 8),
          ),
        ],
      );
      expect(r.isClosed, isTrue);
      expect(r.closedOn, DateTime(2026, 10, 8));
    });

    test('fractional quantities close without float drift', () {
      final r = rental(
        issued: DateTime(2026, 10, 1),
        expires: DateTime(2026, 10, 31),
        items: const [
          RentalItem(id: 'a', name: 'Palagai', qty: 0.3, unit: 'ft'),
        ],
        returns: [
          ReturnEntry(
            id: 'x1',
            itemId: 'a',
            qty: 0.1,
            date: DateTime(2026, 10, 2),
          ),
          ReturnEntry(
            id: 'x2',
            itemId: 'a',
            qty: 0.2,
            date: DateTime(2026, 10, 3),
          ),
        ],
      );
      expect(r.isClosed, isTrue);
    });

    test('a rental with no items is never closed', () {
      final r = rental(issued: today, expires: today, items: const []);
      expect(r.isClosed, isFalse);
    });

    test('serialises to native maps and back', () {
      final r = rental(
        issued: DateTime(2026, 10, 1),
        expires: DateTime(2026, 10, 31),
        returns: [
          ReturnEntry(
            id: 'x1',
            itemId: 'a',
            qty: 5,
            date: DateTime(2026, 10, 2),
            note: 'ok',
          ),
        ],
      );
      final map = r.toMap();
      expect(map['items'], isA<List<dynamic>>());
      expect(map['expiresOn'], '2026-10-31');
      final back = Rental.tryFromMap('r1', map)!;
      expect(back.dcNumber, 'SD-1001');
      expect(back.expiresOn, DateTime(2026, 10, 31));
      expect(back.returnedQty('a'), 5);
      expect(back.returns.single.note, 'ok');
    });

    test('malformed documents are rejected or cleaned, never crash', () {
      expect(Rental.tryFromMap('x', {'dcNumber': 'SD-1'}), isNull);
      final r = Rental.tryFromMap('x', {
        'dcNumber': 'SD-1',
        'customerId': 'c',
        'issuedOn': '2026-10-01',
        'expiresOn': '2026-10-10',
        'items': [
          {'id': 'a', 'name': 'Props', 'qty': 3},
          {'garbage': true},
          'not a map',
        ],
        'returns': 'not a list',
      })!;
      expect(r.items, hasLength(1));
      expect(r.returns, isEmpty);
    });
  });

  group('expiry status', () {
    ExpiryStatus status(int expiresInDays, {bool closed = false}) {
      final r = rental(
        issued: addDays(today, -10),
        expires: addDays(today, expiresInDays),
        returns: closed
            ? [ReturnEntry(id: 'x', itemId: 'a', qty: 40, date: today)]
            : const [],
      );
      return expiryOf(r, today: today, soonDays: 3).status;
    }

    test('classifies by days left', () {
      expect(status(-1), ExpiryStatus.expired);
      expect(status(0), ExpiryStatus.dueToday);
      expect(status(1), ExpiryStatus.dueSoon);
      expect(status(3), ExpiryStatus.dueSoon);
      expect(status(4), ExpiryStatus.active);
      expect(status(-5, closed: true), ExpiryStatus.closed);
    });

    test('labels', () {
      ExpiryInfo info(int d) => expiryOf(
        rental(issued: addDays(today, -30), expires: addDays(today, d)),
        today: today,
        soonDays: 3,
      );
      expect(info(-1).label, '1 day overdue');
      expect(info(-4).label, '4 days overdue');
      expect(info(0).label, 'Expires today');
      expect(info(1).label, '1 day left');
      expect(info(10).label, '10 days left');
    });
  });

  group('reminder plan', () {
    final now = DateTime(2026, 10, 9, 8, 0);

    test('three reminders per open rental at the chosen time', () {
      final r = rental(
        issued: DateTime(2026, 10, 1),
        expires: DateTime(2026, 10, 20),
      );
      final plan = planReminders(
        [r],
        now: now,
        leadDays: 3,
        hour: 9,
        minute: 30,
      );
      expect(plan.map((p) => p.kind), [
        ReminderKind.beforeExpiry,
        ReminderKind.onExpiry,
        ReminderKind.afterExpiry,
      ]);
      expect(plan.map((p) => p.fireAt), [
        DateTime(2026, 10, 17, 9, 30),
        DateTime(2026, 10, 20, 9, 30),
        DateTime(2026, 10, 21, 9, 30),
      ]);
      // Ids are fixed per delivery and kind, so a re-plan never replaces
      // a reminder still unread in the notification shade.
      expect(
        plan.map((p) => p.id),
        plan.map((p) => reminderId(p.rentalId, p.kind)),
      );
      expect(plan.map((p) => p.id).toSet(), hasLength(3));
      expect(plan.every((p) => p.id > 0 && p.id <= 0x7FFFFFFF), isTrue);
      expect(plan.first.rentalId, 'r1');
      expect(plan.first.body, contains('Murugan'));
    });

    test('past times are skipped; today later still fires', () {
      final r = rental(
        issued: DateTime(2026, 10, 1),
        expires: DateTime(2026, 10, 9),
      );
      final plan = planReminders(
        [r],
        now: now,
        leadDays: 3,
        hour: 9,
        minute: 0,
      );
      expect(plan.map((p) => p.kind), [
        ReminderKind.onExpiry,
        ReminderKind.afterExpiry,
      ]);
    });

    test('closed rentals get no reminders', () {
      final r = rental(
        issued: DateTime(2026, 10, 1),
        expires: DateTime(2026, 10, 20),
        returns: [
          ReturnEntry(
            id: 'x',
            itemId: 'a',
            qty: 40,
            date: DateTime(2026, 10, 5),
          ),
        ],
      );
      expect(
        planReminders([r], now: now, leadDays: 3, hour: 9, minute: 0),
        isEmpty,
      );
    });

    test('capped and soonest first', () {
      final rentals = [
        for (var i = 0; i < 40; i++)
          rental(
            id: 'r$i',
            dc: 'SD-${1000 + i}',
            issued: DateTime(2026, 10, 1),
            expires: addDays(DateTime(2026, 10, 15), i),
          ),
      ];
      final plan = planReminders(
        rentals,
        now: now,
        leadDays: 2,
        hour: 9,
        minute: 0,
      );
      expect(plan, hasLength(maxScheduledReminders));
      for (var i = 1; i < plan.length; i++) {
        expect(plan[i].fireAt.isBefore(plan[i - 1].fireAt), isFalse);
      }
      expect(plan.map((p) => p.id).toSet(), hasLength(plan.length));
    });
  });

  group('DC numbers', () {
    test('next number follows the highest existing one', () {
      final rs = [
        rental(id: '1', dc: 'SD-1001', issued: today, expires: today),
        rental(id: '2', dc: 'SD-1007', issued: today, expires: today),
        rental(id: '3', dc: 'OLD-9999', issued: today, expires: today),
      ];
      expect(nextDcNumber(rs, prefix: 'SD-', start: 1001), 'SD-1008');
      expect(nextDcNumber(const [], prefix: 'SD-', start: 1001), 'SD-1001');
    });

    test('duplicate check ignores case and the record being edited', () {
      final rs = [
        rental(id: '1', dc: 'SD-1001', issued: today, expires: today),
      ];
      expect(isDcNumberTaken(rs, 'sd-1001 '), isTrue);
      expect(isDcNumberTaken(rs, 'SD-1001', exceptId: '1'), isFalse);
    });
  });

  group('phones', () {
    test('match with or without country code', () {
      expect(phoneKey('+91 98400 12345'), phoneKey('9840012345'));
      expect(normalizePhone(' +91 98400-12345 '), '+919840012345');
    });
  });
}
