import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sd_centring/app.dart';
import 'package:sd_centring/core/dates.dart';
import 'package:sd_centring/data/demo_data.dart';
import 'package:sd_centring/data/memory_repository.dart';
import 'package:sd_centring/data/repository.dart';
import 'package:sd_centring/domain/expiry.dart';
import 'package:sd_centring/models/customer.dart';
import 'package:sd_centring/models/rental.dart';
import 'package:sd_centring/services/reminder_scheduler.dart';
import 'package:sd_centring/state/app_state.dart';
import 'package:sd_centring/state/settings.dart';
import 'package:sd_centring/ui/screens/home_shell.dart';
import 'package:sd_centring/ui/theme.dart';
import 'package:sd_centring/ui/widgets/rental_tile.dart';

/// Memory repository whose sync state and load errors tests can control.
class ControlledRepository extends MemoryRepository {
  ControlledRepository({super.customers, super.rentals, this.failLoad = false});

  final bool failLoad;
  final syncState = ValueNotifier<SyncState>(SyncState.synced);

  @override
  bool get isDemo => false;

  @override
  ValueListenable<SyncState> get sync => syncState;

  @override
  Stream<List<Rental>> watchRentals() => failLoad
      ? Stream.error(
          Exception('[cloud_firestore/permission-denied] Missing permissions'),
        )
      : super.watchRentals();
}

class Harness {
  Harness(this.repo, {DateTime Function()? clock})
    : settings = ReminderSettings.inMemory(),
      scheduler = NoopReminderScheduler() {
    app = AppState(
      repo: repo,
      settings: settings,
      scheduler: scheduler,
      clock: clock,
    );
  }

  final Repository repo;
  final ReminderSettings settings;
  final NoopReminderScheduler scheduler;
  late final AppState app;

  Widget widget({Size? size, Brightness brightness = Brightness.light}) {
    Widget child = MultiProvider(
      providers: [
        ChangeNotifierProvider<ReminderSettings>.value(value: settings),
        ChangeNotifierProvider<AppState>.value(value: app),
      ],
      child: MaterialApp(
        theme: buildTheme(brightness),
        home: const HomeShell(),
      ),
    );
    if (size != null) {
      child = MediaQuery(
        data: MediaQueryData(size: size),
        child: child,
      );
    }
    return child;
  }
}

Harness demoHarness({DateTime Function()? clock}) {
  final demo = demoData(todayDate());
  return Harness(
    MemoryRepository(customers: demo.customers, rentals: demo.rentals),
    clock: clock,
  );
}

Future<void> openDelivery(WidgetTester tester, String dc) async {
  await tester.tap(find.text('Deliveries').last);
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).first, dc);
  await tester.pumpAndSettle();
  await tester.tap(tileText(dc));
  await tester.pumpAndSettle();
}

/// Text inside a delivery card (not the search box).
Finder tileText(String text) =>
    find.descendant(of: find.byType(RentalTile), matching: find.text(text));

Future<void> scrollTo(WidgetTester tester, Finder f) =>
    tester.scrollUntilVisible(f, 150, scrollable: find.byType(Scrollable).last);

/// Pumps [h] (demo data by default), runs [body], then tears everything
/// down so no timers or listeners leak between tests.
void appTest(
  String name,
  Future<void> Function(WidgetTester tester, Harness h) body, {
  Harness Function()? harness,
  Size? surface,
  Brightness brightness = Brightness.light,
}) {
  testWidgets(name, (tester) async {
    if (surface != null) {
      tester.view.physicalSize = surface;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }
    final h = (harness ?? demoHarness)();
    await tester.pumpWidget(h.widget(brightness: brightness));
    await tester.pumpAndSettle();
    await body(tester, h);
    await tester.pumpWidget(const SizedBox());
    h.app.dispose();
  });
}

void main() {
  group('Delivery screens', () {
    appTest('undo a return puts material back out', (tester, h) async {
      await openDelivery(tester, 'SD-1001');

      expect(find.textContaining('Returned 15 of 40'), findsOneWidget);
      await scrollTo(tester, find.byTooltip('Undo this return'));
      await tester.tap(find.byTooltip('Undo this return'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Undo'));
      await tester.pumpAndSettle();
      await scrollTo(tester, find.textContaining('Returned 0 of 40'));
      expect(find.textContaining('Returned 0 of 40'), findsOneWidget);
      expect(h.app.rentalById('demo-r1')!.returns, isEmpty);
    });

    appTest('return more than outstanding is rejected', (tester, h) async {
      await openDelivery(tester, 'SD-1001');

      await tester.tap(find.text('Record return'));
      await tester.pumpAndSettle();
      // Props: 25 still out.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Qty').last,
        '26',
      );
      await tester.tap(find.text('Save return'));
      await tester.pumpAndSettle();
      expect(find.text('Max 25'), findsOneWidget);
      expect(h.app.rentalById('demo-r1')!.returns, hasLength(1));
    });

    appTest('saving a return with nothing entered asks for a quantity', (
      tester,
      h,
    ) async {
      await openDelivery(tester, 'SD-1003');
      await tester.tap(find.text('Record return'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save return'));
      await tester.pumpAndSettle();
      expect(
        find.text('Enter a quantity for at least one item'),
        findsOneWidget,
      );
    });

    appTest('editing cannot lower a quantity below what was returned', (
      tester,
      h,
    ) async {
      await openDelivery(tester, 'SD-1001');

      await tester.tap(find.byTooltip('Edit'));
      await tester.pumpAndSettle();
      // Second item is Props (40, 15 returned).
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Qty').at(1),
        '10',
      );
      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();
      expect(find.textContaining('already returned'), findsOneWidget);
      expect(h.app.rentalById('demo-r1')!.items[1].qty, 40);
    });

    appTest('duplicate DC number is refused', (tester, h) async {
      await tester.tap(find.text('New delivery'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'DC number'),
        'sd-1002',
      );
      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();
      expect(find.text('Already used'), findsOneWidget);
    });

    appTest('leaving a half-filled form asks before discarding', (
      tester,
      h,
    ) async {
      final before = h.app.rentals.length;
      await tester.tap(find.text('New delivery'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Site (optional)'),
        'Guindy',
      );
      await tester.pump();
      await tester.binding.handlePopRoute(); // Android back button
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(find.text('New delivery'), findsWidgets);
      expect(h.app.rentals.length, before);
    });

    appTest('delete a delivery', (tester, h) async {
      await openDelivery(tester, 'SD-1004');
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete delivery'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(h.app.rentalById('demo-r4'), isNull);
      expect(tileText('SD-1004'), findsNothing);
    });
  });

  group('Lists, search and filters', () {
    appTest('filter chips and search narrow the list', (tester, h) async {
      await tester.tap(find.text('Deliveries'));
      await tester.pumpAndSettle();

      // "Out on rent" shows the 4 open ones, not the returned one.
      expect(find.text('SD-1005'), findsNothing);
      expect(find.text('SD-1001'), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Returned'));
      await tester.pumpAndSettle();
      expect(find.text('SD-1005'), findsOneWidget);
      expect(find.text('SD-1001'), findsNothing);

      await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'velach');
      await tester.pumpAndSettle();
      expect(find.text('SD-1002'), findsOneWidget);
      expect(find.text('SD-1001'), findsNothing);

      // Phone search.
      await tester.enterText(find.byType(TextField).first, '98400 12345');
      await tester.pumpAndSettle();
      expect(find.text('SD-1001'), findsOneWidget);
      expect(find.text('SD-1004'), findsOneWidget);
      expect(find.text('SD-1002'), findsNothing);

      await tester.enterText(find.byType(TextField).first, 'zzzz');
      await tester.pumpAndSettle();
      expect(find.text('No matches'), findsOneWidget);
    });

    appTest('Alerts tiles jump to the matching filter', (tester, h) async {
      await tester.tap(find.text('Expired'));
      await tester.pumpAndSettle();
      final chip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Expired'),
      );
      expect(chip.selected, isTrue);
      expect(find.text('SD-1001'), findsOneWidget);
      expect(find.text('SD-1004'), findsNothing);
    });

    appTest(
      'empty database shows friendly empty states',
      harness: () => Harness(MemoryRepository()),
      (tester, h) async {
        expect(find.text('All clear'), findsOneWidget);
        await tester.tap(find.text('Customers'));
        await tester.pumpAndSettle();
        expect(find.text('No customers yet'), findsOneWidget);
      },
    );
  });

  group('Customers', () {
    appTest('cannot delete a customer with deliveries', (tester, h) async {
      await tester.tap(find.text('Customers'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ravi Kumar'));
      await tester.pumpAndSettle();
      expect(find.text('MATERIAL WITH CUSTOMER'), findsOneWidget);
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete customer'));
      await tester.pumpAndSettle();
      expect(find.textContaining('cannot be deleted'), findsOneWidget);
      expect(h.app.customerById('demo-c3'), isNotNull);
    });

    appTest('new customer validates phone and warns on duplicates', (
      tester,
      h,
    ) async {
      await tester.tap(find.text('Customers'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('New customer'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name *'),
        'Selvam',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Phone *'),
        '12345',
      );
      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid phone number'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Phone *'),
        '+91 98400 12345',
      );
      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();
      expect(find.text('Phone number already used'), findsOneWidget);
      await tester.tap(find.text('Save anyway'));
      await tester.pumpAndSettle();
      expect(h.app.customers.any((c) => c.name == 'Selvam'), isTrue);
      expect(find.text('Selvam'), findsOneWidget);
    });

    appTest('renaming a customer updates their deliveries', (tester, h) async {
      final c = h.app.customerById('demo-c2')!;
      await h.app.saveCustomer(c.copyWith(name: 'Lakshmi Infra'));
      await tester.pumpAndSettle();
      expect(find.text('Lakshmi Infra'), findsWidgets);
      expect(find.text('Lakshmi Constructions'), findsNothing);
    });
  });

  group('Cloud sync visibility', () {
    final repo = ControlledRepository(
      customers: [
        Customer(
          id: 'c',
          name: 'A',
          phone: '9000000000',
          createdAt: DateTime(2026),
        ),
      ],
    );
    appTest(
      'pending and offline states are shown',
      harness: () => Harness(repo),
      (tester, h) async {
        expect(find.text('Waiting to sync'), findsNothing);

        repo.syncState.value = SyncState.pending;
        await tester.pumpAndSettle();
        expect(find.text('Waiting to sync'), findsOneWidget);

        repo.syncState.value = SyncState.offline;
        await tester.pumpAndSettle();
        expect(find.text('Offline'), findsOneWidget);

        repo.syncState.value = SyncState.synced;
        await tester.pumpAndSettle();
        expect(find.text('Offline'), findsNothing);
      },
    );

    appTest(
      'a database refusal stays visible, never silent',
      harness: () => Harness(ControlledRepository(failLoad: true)),
      (tester, h) async {
        expect(find.text('Not saving to cloud'), findsOneWidget);
        expect(find.textContaining('NOT being saved'), findsOneWidget);
        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();
        expect(find.text('Not saving to cloud'), findsOneWidget);
      },
    );
  });

  group('Layout and theme', () {
    appTest(
      'wide screens use a navigation rail',
      surface: const Size(1280, 800),
      (tester, h) async {
        expect(find.byType(NavigationRail), findsOneWidget);
        expect(find.byType(NavigationBar), findsNothing);
      },
    );

    appTest(
      'small phone and dark mode render without overflow',
      surface: const Size(320, 568),
      brightness: Brightness.dark,
      (tester, h) async {
        for (final tab in ['Deliveries', 'Customers', 'Settings', 'Alerts']) {
          await tester.tap(find.text(tab).last);
          await tester.pumpAndSettle();
        }
        await openDelivery(tester, 'SD-1001');
        await tester.tap(find.byTooltip('Edit'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    appTest(
      'large text (accessibility) does not break the main screens',
      surface: const Size(360, 780),
      (tester, h) async {
        tester.platformDispatcher.textScaleFactorTestValue = 1.6;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpAndSettle();
        for (final tab in ['Deliveries', 'Customers', 'Settings', 'Alerts']) {
          await tester.tap(find.text(tab).last);
          await tester.pumpAndSettle();
        }
        await openDelivery(tester, 'SD-1001');
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('Notifications', () {
    testWidgets('tapping a reminder opens that delivery', (tester) async {
      await tester.pumpWidget(
        SdApp(
          firebaseReady: false,
          settings: ReminderSettings.inMemory(),
          scheduler: NoopReminderScheduler(),
        ),
      );
      await tester.pumpAndSettle();
      pendingRentalId.value = 'demo-r3';
      await tester.pumpAndSettle();
      expect(find.text('SD-1003'), findsWidgets);
      expect(find.text('Record return'), findsOneWidget);
      expect(pendingRentalId.value, isNull);
    });

    testWidgets('reminder for a deleted delivery shows "not found"', (
      tester,
    ) async {
      await tester.pumpWidget(
        SdApp(
          firebaseReady: false,
          settings: ReminderSettings.inMemory(),
          scheduler: NoopReminderScheduler(),
        ),
      );
      await tester.pumpAndSettle();
      pendingRentalId.value = 'gone';
      await tester.pumpAndSettle();
      expect(find.text('Delivery not found'), findsOneWidget);
    });
  });

  group('AppState behaviour', () {
    test(
      'extending expiry clears the overdue state and logs history',
      () async {
        final h = demoHarness();
        await Future<void>.delayed(Duration.zero);
        final r = h.app.rentalById('demo-r1')!;
        expect(h.app.expiry(r).status, ExpiryStatus.expired);
        await h.app.changeExpiry(r, addDays(h.app.today, 10));
        await Future<void>.delayed(Duration.zero);
        final updated = h.app.rentalById('demo-r1')!;
        expect(h.app.expiry(updated).status, ExpiryStatus.active);
        expect(updated.expiryHistory.single.from, r.expiresOn);
        // Same date again is a no-op, not another history entry.
        await h.app.changeExpiry(updated, updated.expiresOn);
        await Future<void>.delayed(Duration.zero);
        expect(h.app.rentalById('demo-r1')!.expiryHistory, hasLength(1));
      },
    );

    test('statuses move forward when the day changes', () async {
      var now = DateTime.now();
      final h = demoHarness(clock: () => now);
      await Future<void>.delayed(Duration.zero);
      final r = h.app.rentalById('demo-r3')!; // expires in 2 days
      expect(h.app.expiry(r).status, ExpiryStatus.dueSoon);
      now = now.add(const Duration(days: 2));
      h.app.refresh();
      expect(h.app.expiry(r).status, ExpiryStatus.dueToday);
      now = now.add(const Duration(days: 1));
      expect(h.app.expiry(r).status, ExpiryStatus.expired);
    });

    test('changing reminder settings re-plans notifications', () async {
      final h = demoHarness();
      await Future<void>.delayed(const Duration(milliseconds: 700));
      final before = h.scheduler.lastPlan.first.fireAt;
      await h.settings.setReminderTime(18, 30);
      await Future<void>.delayed(const Duration(milliseconds: 700));
      expect(
        h.scheduler.lastPlan.every(
          (p) => p.fireAt.hour == 18 && p.fireAt.minute == 30,
        ),
        isTrue,
      );
      expect(h.scheduler.lastPlan.first.fireAt, isNot(before));
    });

    test('write failures reach the user', () async {
      final repo = _FailingWrites();
      final h = Harness(repo);
      await Future<void>.delayed(Duration.zero);
      repo.fail('Could not save delivery. Please check your connection.');
      await Future<void>.delayed(Duration.zero);
      expect(h.app.takeError(), contains('Could not save delivery'));
      expect(h.app.takeError(), isNull, reason: 'shown once');
    });
  });
}

class _FailingWrites extends MemoryRepository {
  final _ctrl = StreamController<String>.broadcast();
  void fail(String msg) => _ctrl.add(msg);
  @override
  Stream<String> get writeErrors => _ctrl.stream;
}
