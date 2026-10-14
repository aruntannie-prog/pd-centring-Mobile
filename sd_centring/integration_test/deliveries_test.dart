// Delivery journeys in the real app (demo data): creating a delivery,
// returns and undo, extending expiry, the WhatsApp preview, filters, search
// and deleting.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sd_centring/core/dates.dart';
import 'package:sd_centring/ui/screens/deliveries_screen.dart';
import 'package:sd_centring/ui/screens/delivery_detail_screen.dart';
import 'package:sd_centring/ui/screens/delivery_form_screen.dart';

import 'support.dart';

Finder get searchBox => find.descendant(
  of: find.byType(DeliveriesScreen),
  matching: find.byType(TextField),
);

Future<void> openDelivery(WidgetTester tester, String dc) async {
  await goToTab(tester, 'Deliveries');
  await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
  await settle(tester);
  await typeInto(tester, searchBox.first, dc);
  await settle(tester);
  await tapOn(tester, tileText(dc), scrollable: listIn(DeliveriesScreen));
  expect(find.byType(DeliveryDetailScreen), findsOneWidget);
}

void main() {
  initIntegrationTests();

  journey('create a delivery: suggested DC number, customer, material '
      'chips and stepper, then it is listed', (tester) async {
    await launchApp(tester);
    await tester.tap(find.widgetWithText(FloatingActionButton, 'New delivery'));
    await settle(tester);
    expect(find.byType(DeliveryFormScreen), findsOneWidget);

    // Next free DC number is suggested (demo has SD-1001..SD-1005).
    expect(fieldText(tester, fieldLabelled('DC number')), 'SD-1006');

    // Saving without a customer or items is refused.
    await tester.tap(find.widgetWithText(TextButton, 'SAVE'));
    await settle(tester);
    expect(find.text('Choose a customer'), findsOneWidget);

    // Choose an existing customer.
    await tester.tap(find.text('Choose customer'));
    await settle(tester);
    await tester.tap(find.text('Ravi Kumar').last);
    await settle(tester);
    expect(find.text('Choose a customer'), findsNothing);

    await typeInto(tester, fieldLabelled('Site (optional)'), 'Guindy');
    final form = listIn(DeliveryFormScreen);
    await tapOn(tester, find.text('15 days'), scrollable: form);

    // Material from a chip, quantity with the stepper.
    await tapOn(
      tester,
      find.widgetWithText(ActionChip, 'Column Box'),
      scrollable: form,
    );
    await reveal(
      tester,
      find.byKey(const ValueKey('item-qty-0')),
      scrollable: form,
    );
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byTooltip('More').first);
      await tester.pump();
    }
    expect(fieldText(tester, find.byKey(const ValueKey('item-qty-0'))), '3');

    await tester.tap(find.widgetWithText(TextButton, 'SAVE'));
    await settle(tester);
    final expires = addDays(todayDate(), 15);
    expect(
      find.text('SD-1006 saved · expires ${formatDay(expires)}'),
      findsOneWidget,
    );

    await openDelivery(tester, 'SD-1006');
    expect(find.text('Ravi Kumar'), findsWidgets);
    expect(find.textContaining('Guindy'), findsWidgets);
    expect(find.textContaining('Column Box'), findsWidgets);
  });

  journey('returns: too many refused, partial return saved, then undone', (
    tester,
  ) async {
    await launchApp(tester);
    await openDelivery(tester, 'SD-1001');
    final detail = listIn(DeliveryDetailScreen);
    await reveal(
      tester,
      find.textContaining('Returned 15 of 40'),
      scrollable: detail,
    );

    await tapOn(tester, find.text('Record return'), scrollable: detail);
    expect(find.text('Save return'), findsOneWidget);
    // Props: 25 still out.
    await typeInto(tester, find.byKey(const ValueKey('return-qty-i2')), '26');
    await tester.tap(find.text('Save return'));
    await settle(tester);
    expect(find.text('Max 25'), findsOneWidget);

    await typeInto(tester, find.byKey(const ValueKey('return-qty-i2')), '5');
    await tester.tap(find.text('Save return'));
    await settle(tester);
    expect(find.text('Save return'), findsNothing);
    await reveal(
      tester,
      find.textContaining('Returned 20 of 40'),
      scrollable: detail,
    );
    expect(find.textContaining('Returned 20 of 40'), findsOneWidget);

    // Undo one return; whichever it is, 20 is no longer the total.
    await tapOn(tester, find.byTooltip('Undo this return'), scrollable: detail);
    expect(find.text('Undo this return?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Undo'));
    await settle(tester);
    expect(find.textContaining('Returned 20 of 40'), findsNothing);
    final left = find.textContaining(RegExp(r'Returned (15|5) of 40'));
    await reveal(tester, left, scrollable: detail);
    expect(left, findsOneWidget);
  });

  journey('extend expiry clears the overdue state and keeps a history', (
    tester,
  ) async {
    await launchApp(tester);
    await openDelivery(tester, 'SD-1001');
    expect(find.textContaining('overdue'), findsWidgets);

    await clearSnackBars(tester);
    await tester.tap(find.text('Extend'));
    await settle(tester);
    final newDate = addDays(todayDate(), 10);
    await enterDateInPicker(tester, newDate);
    expect(find.text('Expiry set to ${formatDay(newDate)}'), findsOneWidget);
    expect(find.textContaining('overdue'), findsNothing);
    final detail = listIn(DeliveryDetailScreen);
    await reveal(tester, find.textContaining('Changed on'), scrollable: detail);
    expect(find.textContaining('Changed on'), findsOneWidget);
  });

  journey('WhatsApp reminder shows the message to send, without prices', (
    tester,
  ) async {
    await launchApp(tester);
    await openDelivery(tester, 'SD-1001');
    await clearSnackBars(tester);
    await tester.tap(find.text('WhatsApp'));
    await settle(tester);
    expect(find.text('Open WhatsApp'), findsOneWidget);
    expect(find.text('To Murugan Builders · +919840012345'), findsOneWidget);
    final message = fieldText(
      tester,
      find.widgetWithText(TextField, 'Message (you can edit it)'),
    );
    expect(message, contains('SD-1001'));
    expect(message, contains('Props'));
    expect(message.contains('₹') || message.contains('Rs'), isFalse);
    await dismissBottomSheet(tester);
    expect(find.text('Open WhatsApp'), findsNothing);
  });

  journey('filters and search narrow the deliveries list', (tester) async {
    await launchApp(tester);
    await goToTab(tester, 'Deliveries');
    expect(tileText('SD-1001'), findsOneWidget);
    expect(tileText('SD-1005'), findsNothing); // returned, not "out"

    await tester.tap(find.widgetWithText(ChoiceChip, 'Returned'));
    await settle(tester);
    expect(tileText('SD-1005'), findsOneWidget);
    expect(tileText('SD-1001'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
    await settle(tester);
    await typeInto(tester, searchBox.first, 'velach');
    await settle(tester);
    expect(tileText('SD-1002'), findsOneWidget);
    expect(tileText('SD-1001'), findsNothing);

    // A DC number does not also match phone numbers.
    await typeInto(tester, searchBox.first, 'SD-1001');
    await settle(tester);
    expect(tileText('SD-1001'), findsOneWidget);
    expect(tileText('SD-1004'), findsNothing);
  });

  journey('delete a delivery', (tester) async {
    await launchApp(tester);
    await openDelivery(tester, 'SD-1004');
    await tester.tap(
      find.descendant(
        of: find.byType(DeliveryDetailScreen),
        matching: find.byType(PopupMenuButton<String>),
      ),
    );
    await settle(tester);
    await tester.tap(find.text('Delete delivery'));
    await settle(tester);
    expect(find.text('Delete SD-1004?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await settle(tester);
    expect(find.byType(DeliveryDetailScreen), findsNothing);
    await typeInto(tester, searchBox.first, 'SD-1004');
    await settle(tester);
    expect(tileText('SD-1004'), findsNothing);
  });
}
