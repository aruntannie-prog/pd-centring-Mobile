// Shared helpers for the end-to-end integration tests.
//
// Every test starts the real app through `main()` (lib/main.dart), so the
// genuine startup path runs: Firebase initialisation fails (placeholder
// options), the app falls back to demo mode with sample data, and reminder
// settings / drafts are loaded from SharedPreferences (localStorage on web).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sd_centring/app.dart' show pendingRentalId;
import 'package:sd_centring/main.dart' as app;
import 'package:sd_centring/ui/widgets/rental_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Initialises the integration test binding and, once every test in the
/// file has run, attaches a per-test PASS/FAIL map to the data sent to the
/// `flutter drive` host (printed by test_driver/integration_test.dart).
void initIntegrationTests() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  tearDownAll(() {
    binding.reportData = {
      ...?binding.reportData,
      'results': {
        for (final e in binding.results.entries)
          e.key: e.value == 'success' ? 'success' : 'failed',
      },
      // Why each test failed, so optimised (release) builds, whose failure
      // reports are empty, still say what went wrong.
      'why': _why,
    };
  });
}

final _why = <String, String>{};

/// Declares one journey. Like [testWidgets], but keeps the failure message
/// itself: optimised (release) builds send no failure details to the
/// driver, which then cannot say why a test failed.
void journey(String name, Future<void> Function(WidgetTester tester) body) {
  testWidgets(name, (tester) async {
    try {
      await body(tester);
    } catch (e, st) {
      final trace = st.toString().split('\n').take(6).join('\n');
      _why[name] = '$e\n$trace';
      rethrow;
    }
  });
}

/// Starts the app the way a user does. The previous test's widget tree is
/// torn down first, so each test gets a fresh demo session (the in-memory
/// demo repository lives in the session state).
///
/// [clearStorage] wipes SharedPreferences first (reminder settings and form
/// drafts). Pass false to simulate re-opening the app on the same device.
Future<void> launchApp(WidgetTester tester, {bool clearStorage = true}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
  pendingRentalId.value = null;
  if (clearStorage) {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
  await app.main();
  await settle(tester);
}

/// pumpAndSettle plus one extra short pump for stream deliveries and the
/// 600 ms reminder re-plan debounce in AppState.
Future<void> settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pumpAndSettle();
}

/// A destination in the bottom navigation bar (phones) or navigation rail
/// (wide windows).
Finder navItem(String label) => find.descendant(
  of: find.byWidgetPredicate((w) => w is NavigationBar || w is NavigationRail),
  matching: find.text(label),
);

Future<void> goToTab(WidgetTester tester, String label) async {
  await clearSnackBars(tester);
  await tester.tap(navItem(label));
  await settle(tester);
}

/// Text inside a delivery card (not the search box or an app bar).
Finder tileText(String text) =>
    find.descendant(of: find.byType(RentalTile), matching: find.text(text));

/// The delivery card showing [dcNumber].
Finder tileFor(String dcNumber) =>
    find.ancestor(of: tileText(dcNumber), matching: find.byType(RentalTile));

/// Nearest vertical scrollable around [anchor].
Finder verticalScrollableOf(Finder anchor) => find
    .ancestor(
      of: anchor,
      matching: find.byWidgetPredicate(
        (w) =>
            w is Scrollable &&
            axisDirectionToAxis(w.axisDirection) == Axis.vertical,
      ),
    )
    .first;

/// Scrolls [target] to the middle of its scrollable. If it is not built yet
/// (lazy lists), [scrollable] is scrolled from the top in 200 px steps until
/// it appears. Scrolling is done on the scroll position directly so it is
/// deterministic in a real browser (no fling or touch-slop effects).
Future<void> reveal(
  WidgetTester tester,
  Finder target, {
  Finder? scrollable,
}) async {
  if (target.evaluate().isEmpty) {
    final position = tester
        .state<ScrollableState>(scrollable ?? find.byType(Scrollable).first)
        .position;
    position.jumpTo(position.minScrollExtent);
    await tester.pump();
    while (target.evaluate().isEmpty &&
        position.pixels < position.maxScrollExtent) {
      position.jumpTo(
        (position.pixels + 200).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        ),
      );
      await tester.pump();
    }
    if (target.evaluate().isEmpty) {
      fail('Not found even after scrolling to the end: $target');
    }
  }
  await Scrollable.ensureVisible(tester.element(target.first), alignment: 0.5);
  await tester.pumpAndSettle();
}

/// Reveals and taps [target].
Future<void> tapOn(
  WidgetTester tester,
  Finder target, {
  Finder? scrollable,
}) async {
  await reveal(tester, target, scrollable: scrollable);
  await tester.tap(target.first);
  await settle(tester);
}

/// Hides every snack bar so it cannot cover what the next step taps.
Future<void> clearSnackBars(WidgetTester tester) async {
  for (final s in tester.stateList<ScaffoldMessengerState>(
    find.byType(ScaffoldMessenger),
  )) {
    s.clearSnackBars();
  }
  await tester.pumpAndSettle();
}

/// Current text of the TextField / TextFormField found by [field].
String fieldText(WidgetTester tester, Finder field) => tester
    .widget<EditableText>(
      find.descendant(of: field, matching: find.byType(EditableText)).first,
    )
    .controller
    .text;

/// A TextFormField / TextField by its label text.
Finder fieldLabelled(String label) => find.widgetWithText(TextFormField, label);

/// Picks [date] in an open Material date picker by switching to text input
/// (the calendar grid would need month navigation).
Future<void> enterDateInPicker(WidgetTester tester, DateTime date) async {
  final dialog = find.byType(DatePickerDialog);
  expect(dialog, findsOneWidget);
  await tester.tap(find.byTooltip('Switch to input'));
  await tester.pumpAndSettle();
  final text = MaterialLocalizations.of(tester.element(dialog))
      .formatCompactDate(date);
  await tester.enterText(
    find.descendant(of: dialog, matching: find.byType(TextField)),
    text,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.descendant(of: dialog, matching: find.text('OK')));
  await settle(tester);
}

/// Sets [hour]:[minute] (24 h) in an open Material time picker via its text
/// input mode.
Future<void> enterTimeInPicker(
  WidgetTester tester,
  int hour,
  int minute,
) async {
  final dialog = find.byType(TimePickerDialog);
  expect(dialog, findsOneWidget);
  await tester.tap(find.byTooltip('Switch to text input mode'));
  await tester.pumpAndSettle();
  final fields = find.descendant(of: dialog, matching: find.byType(TextField));
  final use24h = MediaQuery.of(tester.element(dialog)).alwaysUse24HourFormat;
  final shownHour = use24h ? hour : (hour % 12 == 0 ? 12 : hour % 12);
  await tester.enterText(fields.at(0), '$shownHour');
  await tester.pumpAndSettle();
  await tester.enterText(fields.at(1), minute.toString().padLeft(2, '0'));
  await tester.pumpAndSettle();
  if (!use24h) {
    await tester.tap(
      find.descendant(of: dialog, matching: find.text(hour < 12 ? 'AM' : 'PM')),
    );
    await tester.pumpAndSettle();
  }
  await tester.tap(find.descendant(of: dialog, matching: find.text('OK')));
  await settle(tester);
}

/// Closes the top modal bottom sheet the way a user does: tapping the dimmed
/// area above it.
Future<void> dismissBottomSheet(WidgetTester tester) async {
  await tester.tapAt(const Offset(20, 20));
  await settle(tester);
}

/// The main vertical list of [screen] (first vertical Scrollable inside it).
Finder listIn(Type screen) => find
    .descendant(
      of: find.byType(screen),
      matching: find.byWidgetPredicate(
        (w) =>
            w is Scrollable &&
            axisDirectionToAxis(w.axisDirection) == Axis.vertical,
      ),
    )
    .first;

/// True when the window is wide enough for the navigation rail layout.
bool isWide(WidgetTester tester) =>
    tester.view.physicalSize.width / tester.view.devicePixelRatio >= 840;

/// Types into a field the way a user does: focus it, let the browser attach
/// its text input, then enter the text. (`enterText` alone can be dropped in
/// a real browser right after another field lost focus.)
Future<void> typeInto(WidgetTester tester, Finder field, String text) async {
  await tester.tap(field, warnIfMissed: false);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.showKeyboard(field);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.enterText(field, text);
  await tester.pump(const Duration(milliseconds: 50));
}
