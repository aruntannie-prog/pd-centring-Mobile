import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sd_centring/app.dart';
import 'package:sd_centring/data/demo_data.dart';
import 'package:sd_centring/data/memory_repository.dart';
import 'package:sd_centring/models/rental.dart';
import 'package:sd_centring/services/reminder_scheduler.dart';
import 'package:sd_centring/state/app_state.dart';
import 'package:sd_centring/state/settings.dart';

void main() {
  group('AppState', () {
    test('loads, re-plans reminders, and records returns', () async {
      final today = DateTime(2026, 10, 9);
      final demo = demoData(today);
      final repo = MemoryRepository(
        customers: demo.customers,
        rentals: demo.rentals,
      );
      final scheduler = NoopReminderScheduler();
      final app = AppState(
        repo: repo,
        settings: ReminderSettings.inMemory(),
        scheduler: scheduler,
        clock: () => DateTime(2026, 10, 9, 8),
      );
      await Future<void>.delayed(const Duration(milliseconds: 700));

      expect(app.loaded, isTrue);
      // Most overdue first, fully returned last.
      expect(app.rentals.first.dcNumber, 'SD-1001');
      expect(app.rentals.last.dcNumber, 'SD-1005');
      expect(scheduler.lastPlan, isNotEmpty);

      final open = app.rentalById('demo-r2')!;
      await app.addReturns(open, [
        // Return everything: the rental closes and its reminders disappear.
        for (final i in open.items)
          ReturnEntry(id: 'ret-${i.id}', itemId: i.id, qty: i.qty, date: today),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 700));
      expect(app.rentalById('demo-r2')!.isClosed, isTrue);
      expect(scheduler.lastPlan.where((p) => p.rentalId == 'demo-r2'), isEmpty);

      expect(
        await app.deleteCustomer('demo-c1'),
        isFalse,
        reason: 'has deliveries',
      );
      app.dispose();
      repo.dispose();
    });
  });

  testWidgets('demo app shows alerts and opens a delivery', (tester) async {
    await tester.pumpWidget(
      SdApp(
        firebaseReady: false,
        settings: ReminderSettings.inMemory(),
        scheduler: NoopReminderScheduler(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Demo mode'), findsOneWidget);
    expect(find.textContaining('EXPIRED — COLLECT MATERIAL'), findsOneWidget);
    expect(find.text('SD-1001'), findsOneWidget);

    await tester.tap(find.text('SD-1001'));
    await tester.pumpAndSettle();
    expect(find.text('Record return'), findsOneWidget);
    expect(find.text('4 days overdue'), findsOneWidget);
    expect(find.textContaining('Returned 15 of 40'), findsOneWidget);

    await tester.tap(find.text('Record return'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All').first);
    await tester.tap(find.text('Save return'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Returned 24 of 24'), findsOneWidget);

    // Navigate between tabs.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Customers'));
    await tester.pumpAndSettle();
    expect(find.text('Murugan Builders'), findsOneWidget);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Remind me before expiry'), findsOneWidget);
  });

  testWidgets('new delivery form validates and saves', (tester) async {
    await tester.pumpWidget(
      SdApp(
        firebaseReady: false,
        settings: ReminderSettings.inMemory(),
        scheduler: NoopReminderScheduler(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('New delivery'));
    await tester.pumpAndSettle();
    expect(find.text('SD-1006'), findsOneWidget);

    // Saving empty shows errors instead of crashing.
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();
    expect(find.text('Choose a customer'), findsOneWidget);

    await tester.tap(find.text('Choose customer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ravi Kumar'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Item'), 'Props');
    await tester.enterText(find.widgetWithText(TextFormField, 'Qty'), '25');
    await tester.tap(find.text('15 days'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();

    expect(find.textContaining('SD-1006 saved'), findsOneWidget);
  });
}
