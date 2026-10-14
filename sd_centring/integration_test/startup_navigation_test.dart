// Startup in demo mode, the Alerts home screen, tab navigation, demo/sync
// banners and what survives re-opening the app.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sd_centring/ui/screens/alerts_screen.dart';
import 'package:sd_centring/ui/screens/customer_form_screen.dart';
import 'package:sd_centring/ui/screens/customers_screen.dart';
import 'package:sd_centring/ui/screens/settings_screen.dart';

import 'support.dart';

void main() {
  initIntegrationTests();

  journey('starts in demo mode on Alerts with the expired delivery first', (
    tester,
  ) async {
    await launchApp(tester);
    final alerts = listIn(AlertsScreen);

    // Demo fallback is announced; nothing pretends to sync.
    expect(find.text('Demo mode'), findsOneWidget);
    expect(
      find.textContaining('Firebase is not set up yet, so sample data'),
      findsOneWidget,
    );
    expect(find.text('Waiting to sync'), findsNothing);
    expect(find.text('Offline'), findsNothing);
    expect(find.text('Not saving to cloud'), findsNothing);

    // Hero summary: SD-1001 expired + SD-1002 due today.
    expect(find.text('SD Centring'), findsWidgets);
    expect(find.text('2 deliveries need attention'), findsOneWidget);
    for (final legend in ['Expired 1', 'Today 1', 'Soon 1', 'On time 1']) {
      expect(find.text(legend), findsOneWidget, reason: legend);
    }
    // Counter tiles.
    expect(find.text('Next 3 days'), findsOneWidget);
    expect(find.text('Out on rent'), findsOneWidget);

    // Alerts tab carries a badge with the number of expired deliveries.
    expect(
      find.descendant(of: find.byType(Badge), matching: find.text('1')),
      findsOneWidget,
    );

    // Sections, most urgent first.
    await reveal(
      tester,
      find.text('Expired — collect material'),
      scrollable: alerts,
    );
    expect(tileText('SD-1001'), findsOneWidget);
    final expiredTile = tileFor('SD-1001');
    for (final t in [
      'Murugan Builders',
      '4',
      'days late',
      'Column Box 24',
      'Props 25',
    ]) {
      expect(
        find.descendant(of: expiredTile, matching: find.text(t)),
        findsOneWidget,
        reason: 'SD-1001 card shows "$t"',
      );
    }
    expect(
      find.descendant(
        of: expiredTile,
        matching: find.textContaining('Selaiyur'),
      ),
      findsOneWidget,
    );

    await reveal(tester, tileText('SD-1002'), scrollable: alerts);
    expect(
      find.descendant(
        of: tileFor('SD-1002'),
        matching: find.text('Lakshmi Constructions'),
      ),
      findsOneWidget,
    );
    await reveal(tester, find.text('Expiring soon'), scrollable: alerts);
    await reveal(tester, tileText('SD-1003'), scrollable: alerts);
    expect(
      find.descendant(
        of: tileFor('SD-1003'),
        matching: find.text('Palagai 120'),
      ),
      findsOneWidget,
    );
    // On-time and fully returned deliveries are not alerts.
    expect(tileText('SD-1004'), findsNothing);
    expect(tileText('SD-1005'), findsNothing);
    // Visual order: expired above due today above expiring soon.
    final y1 = tester.getTopLeft(tileFor('SD-1001')).dy;
    final y2 = tester.getTopLeft(tileFor('SD-1002')).dy;
    final y3 = tester.getTopLeft(tileFor('SD-1003')).dy;
    expect(y1 < y2 && y2 < y3, isTrue, reason: 'urgency order $y1 $y2 $y3');
  });

  journey('every tab opens with its own content and action button', (
    tester,
  ) async {
    await launchApp(tester);

    // Phone layout has a bottom bar, wide windows a rail.
    if (isWide(tester)) {
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    } else {
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    }

    // Alerts (home).
    expect(find.text('2 deliveries need attention'), findsOneWidget);
    expect(
      find.widgetWithText(FloatingActionButton, 'New delivery'),
      findsOneWidget,
    );

    // Deliveries.
    await goToTab(tester, 'Deliveries');
    expect(find.text('4 out on rent · 1 expired'), findsOneWidget);
    expect(
      find.widgetWithText(
        TextField,
        'Search DC no., customer, site, phone, item',
      ),
      findsOneWidget,
    );
    expect(tileText('SD-1004'), findsOneWidget);
    expect(
      find.widgetWithText(FloatingActionButton, 'New delivery'),
      findsOneWidget,
    );

    // Customers.
    await goToTab(tester, 'Customers');
    expect(find.text('3 customers · 3 without ID proof'), findsOneWidget);
    for (final name in [
      'Lakshmi Constructions',
      'Murugan Builders',
      'Ravi Kumar',
    ]) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
    // A–Z order.
    final ys = [
      for (final n in [
        'Lakshmi Constructions',
        'Murugan Builders',
        'Ravi Kumar',
      ])
        tester.getTopLeft(find.text(n)).dy,
    ];
    expect(ys[0] < ys[1] && ys[1] < ys[2], isTrue);
    expect(
      find.widgetWithText(FloatingActionButton, 'Add customer'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(FloatingActionButton, 'New delivery'),
      findsNothing,
    );

    // Settings.
    await goToTab(tester, 'Settings');
    expect(find.text('Remind me before expiry'), findsOneWidget);
    expect(find.text('Reminder time'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);

    // Back home.
    await goToTab(tester, 'Alerts');
    expect(find.text('2 deliveries need attention'), findsOneWidget);
  });

  journey('Alerts counter tiles jump to the matching Deliveries filter', (
    tester,
  ) async {
    await launchApp(tester);

    await tapOn(
      tester,
      find.descendant(
        of: find.byType(AlertsScreen),
        matching: find.text('Expired'),
      ),
    );
    final expiredChip = find.widgetWithText(ChoiceChip, 'Expired');
    expect(tester.widget<ChoiceChip>(expiredChip).selected, isTrue);
    expect(tileText('SD-1001'), findsOneWidget);
    expect(tileText('SD-1002'), findsNothing);

    await goToTab(tester, 'Alerts');
    await tapOn(tester, find.text('Next 3 days'));
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Expiring'))
          .selected,
      isTrue,
    );
    expect(tileText('SD-1002'), findsOneWidget);
    expect(tileText('SD-1003'), findsOneWidget);
    expect(tileText('SD-1001'), findsNothing);
  });

  journey('demo mode is explained in Settings and no cloud marks appear', (
    tester,
  ) async {
    await launchApp(tester);
    await goToTab(tester, 'Settings');
    final settingsList = listIn(SettingsScreen);

    await reveal(tester, find.text('Cloud sync'), scrollable: settingsList);
    expect(find.text('Demo mode — nothing is saved'), findsOneWidget);
    expect(
      find.text('Connect Firebase to sign in and save data. See README.'),
      findsOneWidget,
    );
    expect(find.text('Sign out'), findsNothing);
    // In the browser, phone notifications are not offered.
    await reveal(
      tester,
      find.text('Phone reminders are in the Android and iOS app'),
      scrollable: settingsList,
    );
    expect(find.text('Allow notifications'), findsNothing);
    await reveal(
      tester,
      find.textContaining('Demo mode: listed here only'),
      scrollable: settingsList,
    );

    // Customer rows: no "In cloud" / "Not in cloud yet" marks in demo mode.
    await goToTab(tester, 'Customers');
    expect(find.text('No ID proof'), findsNWidgets(3));
    expect(find.text('In cloud'), findsNothing);
    expect(find.text('Not in cloud yet'), findsNothing);
  });

  journey('reminder settings and a half-typed customer survive re-opening '
      'the app', (tester) async {
    await launchApp(tester);

    // Change a setting.
    await goToTab(tester, 'Settings');
    await tapOn(tester, find.widgetWithText(ChoiceChip, '7 days'));
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '7 days'))
          .selected,
      isTrue,
    );

    // Start a new customer and leave it half done.
    await goToTab(tester, 'Customers');
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Add customer'));
    await settle(tester);
    expect(find.text('New customer'), findsOneWidget);
    await typeInto(tester, fieldLabelled('Name *'), 'Half Typed Name');
    await typeInto(tester, fieldLabelled('Phone *'), '98765');
    await tester.pumpAndSettle();

    // "Re-open" the app: same device storage, fresh process state.
    await launchApp(tester, clearStorage: false);

    expect(find.text('Next 7 days'), findsOneWidget);
    await goToTab(tester, 'Settings');
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '7 days'))
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '3 days'))
          .selected,
      isFalse,
    );

    await goToTab(tester, 'Customers');
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Add customer'));
    await settle(tester);
    expect(find.text('Restored what you typed earlier'), findsOneWidget);
    expect(fieldText(tester, fieldLabelled('Name *')), 'Half Typed Name');
    expect(fieldText(tester, fieldLabelled('Phone *')), '98765');

    // "Start over" clears the fields and the stored draft.
    await tester.tap(find.text('Start over'));
    await settle(tester);
    expect(find.text('Restored what you typed earlier'), findsNothing);
    expect(fieldText(tester, fieldLabelled('Name *')), '');
    await tester.tap(find.byTooltip('Close'));
    await settle(tester);
    expect(find.byType(CustomerFormScreen), findsNothing);
    expect(find.byType(CustomersScreen), findsOneWidget);

    await launchApp(tester, clearStorage: false);
    await goToTab(tester, 'Customers');
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Add customer'));
    await settle(tester);
    expect(find.text('Restored what you typed earlier'), findsNothing);
    expect(fieldText(tester, fieldLabelled('Name *')), '');
  });
}
