// Customer journeys: adding (validation and duplicate numbers), searching,
// sorting, viewing, editing and deleting.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sd_centring/core/dates.dart';
import 'package:sd_centring/ui/screens/customer_detail_screen.dart';
import 'package:sd_centring/ui/screens/customer_form_screen.dart';
import 'package:sd_centring/ui/screens/customers_screen.dart';
import 'package:sd_centring/ui/screens/delivery_form_screen.dart';

import 'support.dart';

/// Taps the app bar SAVE of the customer form.
Future<void> saveForm(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(TextButton, 'SAVE'));
  await settle(tester);
}

Future<void> openNewCustomerForm(WidgetTester tester) async {
  await goToTab(tester, 'Customers');
  await tester.tap(find.widgetWithText(FloatingActionButton, 'Add customer'));
  await settle(tester);
  expect(find.text('New customer'), findsOneWidget);
}

/// A customer row in the Customers list.
Finder customerRow(String name) => find.descendant(
  of: find.byType(CustomersScreen),
  matching: find.text(name),
);

Future<void> openCustomer(WidgetTester tester, String name) async {
  await goToTab(tester, 'Customers');
  await tapOn(tester, customerRow(name), scrollable: listIn(CustomersScreen));
  expect(find.byType(CustomerDetailScreen), findsOneWidget);
}

Future<void> openCustomerMenuAndDelete(WidgetTester tester) async {
  await clearSnackBars(tester);
  await tester.tap(
    find.descendant(
      of: find.byType(CustomerDetailScreen),
      matching: find.byType(PopupMenuButton<String>),
    ),
  );
  await settle(tester);
  await tester.tap(find.text('Delete customer'));
  await settle(tester);
}

void main() {
  initIntegrationTests();

  journey('add a customer: required fields, phone checks, duplicate '
      'warning, then saved and viewable', (tester) async {
    await launchApp(tester);
    await openNewCustomerForm(tester);

    // Nothing entered.
    await saveForm(tester);
    expect(find.text('Enter the customer name'), findsOneWidget);
    expect(find.text('Enter a phone number'), findsOneWidget);
    expect(find.text('Please fix the highlighted fields.'), findsOneWidget);

    await typeInto(tester, fieldLabelled('Name *'), '  Selvam   Traders ');

    // Phone problems, one at a time.
    for (final (input, message) in [
      ('12345', 'Too short: enter all 10 digits'),
      ('98400 12345 99999', 'Too long: check the number'),
      ('9840+012345', '"+" can only be at the start'),
    ]) {
      await typeInto(tester, fieldLabelled('Phone *'), input);
      await saveForm(tester);
      expect(find.text(message), findsOneWidget, reason: input);
      expect(find.text('Enter the customer name'), findsNothing);
    }
    // Letters cannot even be typed into a phone field.
    await typeInto(tester, fieldLabelled('Phone *'), '98abc40012');
    await tester.pumpAndSettle();
    expect(fieldText(tester, fieldLabelled('Phone *')), '9840012');

    // Alternate number equal to the main one.
    await typeInto(tester, fieldLabelled('Phone *'), '9000011111');
    await typeInto(tester, fieldLabelled('Alternate phone'), '+91 90000 11111');
    await saveForm(tester);
    expect(find.text('Same as the main number'), findsOneWidget);
    await typeInto(tester, fieldLabelled('Alternate phone'), '');

    // Number of an existing customer (other format): warned, can go back.
    await typeInto(tester, fieldLabelled('Phone *'), '+91 98765 43210');
    await saveForm(tester);
    expect(find.text('Number already saved'), findsOneWidget);
    expect(
      find.text('This number belongs to another customer:'),
      findsOneWidget,
    );
    expect(find.text('•  Lakshmi Constructions  9876543210'), findsNothing);
    expect(find.text('• Lakshmi Constructions  9876543210'), findsOneWidget);
    await tester.tap(find.text('Go back'));
    await settle(tester);
    expect(find.text('Number already saved'), findsNothing);
    expect(find.byType(CustomerFormScreen), findsOneWidget);

    // Fix it and save with address and notes.
    await typeInto(tester, fieldLabelled('Phone *'), '90000 11111');
    final form = listIn(CustomerFormScreen);
    await reveal(tester, fieldLabelled('Address'), scrollable: form);
    await typeInto(tester, fieldLabelled('Address'), 'Guindy');
    await reveal(tester, fieldLabelled('Notes'), scrollable: form);
    await typeInto(tester, fieldLabelled('Notes'), 'Pays monthly');
    await saveForm(tester);

    expect(find.byType(CustomerFormScreen), findsNothing);
    expect(find.text('Selvam Traders added'), findsOneWidget);
    expect(find.text('4 customers · 4 without ID proof'), findsOneWidget);
    await reveal(
      tester,
      customerRow('Selvam Traders'),
      scrollable: listIn(CustomersScreen),
    );
    // Stored as digits only; new customer has no rentals yet.
    expect(customerRow('9000011111'), findsOneWidget);
    expect(find.text('No rentals'), findsOneWidget);

    // Sorting: newest first puts the new customer on top, A–Z puts it last.
    await tester.tap(find.widgetWithText(ChoiceChip, 'Newest first'));
    await settle(tester);
    double y(String n) => tester.getTopLeft(customerRow(n)).dy;
    expect(y('Selvam Traders') < y('Lakshmi Constructions'), isTrue);
    await tester.tap(find.widgetWithText(ChoiceChip, 'A–Z'));
    await settle(tester);
    expect(y('Selvam Traders') > y('Ravi Kumar'), isTrue);

    // Open it from the list.
    await tapOn(
      tester,
      customerRow('Selvam Traders'),
      scrollable: listIn(CustomersScreen),
    );
    expect(find.text('Selvam Traders'), findsOneWidget);
    expect(find.text('0 open · 0 returned'), findsOneWidget);
    expect(find.text('Added ${formatDay(todayDate())}'), findsOneWidget);
    expect(find.text('9000011111'), findsOneWidget);
    expect(find.text('Guindy'), findsOneWidget);
    expect(find.text('Pays monthly'), findsOneWidget);
    expect(find.text('No documents yet.'), findsOneWidget);
    await reveal(
      tester,
      find.text('Nothing out on rent.'),
      scrollable: listIn(CustomerDetailScreen),
    );
  });

  journey('snack bar VIEW opens the customer just added', (tester) async {
    await launchApp(tester);
    await openNewCustomerForm(tester);
    await typeInto(tester, fieldLabelled('Name *'), 'Kannan');
    await typeInto(tester, fieldLabelled('Phone *'), '9444455555');
    await saveForm(tester);
    expect(find.text('Kannan added'), findsOneWidget);
    await tester.tap(find.widgetWithText(SnackBarAction, 'VIEW'));
    await settle(tester);
    expect(find.byType(CustomerDetailScreen), findsOneWidget);
    expect(find.text('Kannan'), findsOneWidget);
    expect(find.text('9444455555'), findsOneWidget);
  });

  journey('a customer with deliveries cannot be deleted; one without can', (
    tester,
  ) async {
    await launchApp(tester);

    // Ravi Kumar has SD-1003 open.
    await openCustomer(tester, 'Ravi Kumar');
    expect(find.text('1 open · 0 returned'), findsOneWidget);
    final detail = listIn(CustomerDetailScreen);
    await reveal(
      tester,
      find.text('Material with customer'),
      scrollable: detail,
    );
    expect(find.text('Palagai'), findsOneWidget);
    expect(find.text('120'), findsOneWidget);
    expect(find.text('ft'), findsOneWidget);
    await reveal(tester, tileText('SD-1003'), scrollable: detail);

    await openCustomerMenuAndDelete(tester);
    expect(
      find.text(
        'This customer has deliveries on record and cannot be deleted.',
      ),
      findsOneWidget,
    );
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(CustomerDetailScreen), findsOneWidget);
    await clearSnackBars(tester);
    await tester.pageBack();
    await settle(tester);

    // A new customer sharing Murugan's number: warned, saved anyway.
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Add customer'));
    await settle(tester);
    await typeInto(tester, fieldLabelled('Name *'), 'Temp Customer');
    await typeInto(tester, fieldLabelled('Phone *'), '9840012345');
    await saveForm(tester);
    expect(find.text('Number already saved'), findsOneWidget);
    expect(find.text('• Murugan Builders  9840012345'), findsOneWidget);
    await tester.tap(find.text('Save anyway'));
    await settle(tester);
    expect(find.text('4 customers · 4 without ID proof'), findsOneWidget);

    // Search narrows the list.
    await typeInto(
      tester,
      find.widgetWithText(TextField, 'Search name, phone, address'),
      'temp',
    );
    await settle(tester);
    expect(customerRow('Temp Customer'), findsOneWidget);
    expect(customerRow('Murugan Builders'), findsNothing);

    // Delete: cancel first, then confirm.
    await tapOn(tester, customerRow('Temp Customer'));
    await openCustomerMenuAndDelete(tester);
    expect(find.text('Delete Temp Customer?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await settle(tester);
    expect(find.byType(CustomerDetailScreen), findsOneWidget);

    await openCustomerMenuAndDelete(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await settle(tester);
    expect(find.byType(CustomerDetailScreen), findsNothing);
    expect(customerRow('Temp Customer'), findsNothing);
    expect(find.text('No matches'), findsOneWidget);
    expect(find.text('3 customers · 3 without ID proof'), findsOneWidget);

    // Other searches: phone digits and address.
    final search = find.widgetWithText(
      TextField,
      'Search name, phone, address',
    );
    await typeInto(tester, search, '91234');
    await settle(tester);
    expect(customerRow('Ravi Kumar'), findsOneWidget);
    expect(customerRow('Lakshmi Constructions'), findsNothing);
    await typeInto(tester, search, 'medavakkam');
    await settle(tester);
    expect(customerRow('Lakshmi Constructions'), findsOneWidget);
    expect(customerRow('Ravi Kumar'), findsNothing);
  });

  journey('customer detail lists open and returned deliveries and the '
      'material they hold', (tester) async {
    await launchApp(tester);

    await openCustomer(tester, 'Murugan Builders');
    expect(find.text('2 open · 0 returned'), findsOneWidget);
    expect(find.text('Tambaram'), findsOneWidget);
    final detail = listIn(CustomerDetailScreen);
    await reveal(
      tester,
      find.text('Material with customer'),
      scrollable: detail,
    );
    for (final (item, qty) in [
      ('Column Box', '24'),
      ('Props', '25'),
      ('Span', '18'),
      ('Roof Sheet', '50'),
    ]) {
      await reveal(tester, find.text(item), scrollable: detail);
      final row = find
          .ancestor(of: find.text(item), matching: find.byType(Row))
          .first;
      expect(
        find.descendant(of: row, matching: find.text(qty)),
        findsOneWidget,
        reason: '$item holding',
      );
    }
    await reveal(tester, tileText('SD-1001'), scrollable: detail);
    await reveal(tester, tileText('SD-1004'), scrollable: detail);
    expect(find.text('Returned'), findsNothing);
    await tester.pageBack();
    await settle(tester);

    // Lakshmi: one open, one fully returned.
    await openCustomer(tester, 'Lakshmi Constructions');
    expect(find.text('1 open · 1 returned'), findsOneWidget);
    final detail2 = listIn(CustomerDetailScreen);
    await reveal(tester, tileText('SD-1002'), scrollable: detail2);
    await reveal(tester, tileText('SD-1005'), scrollable: detail2);
    expect(find.text('All 1 item returned'), findsOneWidget);

    // "New DC" opens the delivery form with this customer chosen.
    await tapOn(tester, find.text('New DC'), scrollable: detail2);
    expect(find.byType(DeliveryFormScreen), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(DeliveryFormScreen),
        matching: find.text('Lakshmi Constructions'),
      ),
      findsOneWidget,
    );
    expect(find.text('Choose customer'), findsNothing);
    // Untouched form closes without asking.
    await tester.tap(find.byTooltip('Close'));
    await settle(tester);
    expect(find.byType(DeliveryFormScreen), findsNothing);
    expect(find.byType(CustomerDetailScreen), findsOneWidget);
  });

  journey('editing a customer saves changes and renames their deliveries', (
    tester,
  ) async {
    await launchApp(tester);
    await openCustomer(tester, 'Ravi Kumar');

    await tester.tap(find.byTooltip('Edit'));
    await settle(tester);
    expect(find.text('Edit customer'), findsOneWidget);
    expect(fieldText(tester, fieldLabelled('Name *')), 'Ravi Kumar');
    expect(fieldText(tester, fieldLabelled('Phone *')), '9123456780');
    await typeInto(tester, fieldLabelled('Name *'), 'Ravi Kumar & Sons');
    await reveal(
      tester,
      fieldLabelled('Address'),
      scrollable: listIn(CustomerFormScreen),
    );
    await typeInto(tester, fieldLabelled('Address'), 'Perungudi');
    await saveForm(tester);

    expect(find.byType(CustomerFormScreen), findsNothing);
    expect(find.text('Changes saved'), findsOneWidget);
    expect(find.text('Ravi Kumar & Sons'), findsOneWidget);
    expect(find.text('Perungudi'), findsOneWidget);
    await clearSnackBars(tester);
    await tester.pageBack();
    await settle(tester);

    // The Alerts card for SD-1003 shows the new name.
    await goToTab(tester, 'Alerts');
    await reveal(tester, tileText('SD-1003'));
    expect(
      find.descendant(
        of: tileFor('SD-1003'),
        matching: find.text('Ravi Kumar & Sons'),
      ),
      findsOneWidget,
    );
    expect(find.text('Ravi Kumar'), findsNothing);
  });

  journey('leaving a half-filled customer form asks before discarding', (
    tester,
  ) async {
    await launchApp(tester);
    await openNewCustomerForm(tester);
    await typeInto(tester, fieldLabelled('Name *'), 'Not Saved');
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Close'));
    await settle(tester);
    expect(find.text('Discard this customer?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await settle(tester);
    expect(fieldText(tester, fieldLabelled('Name *')), 'Not Saved');

    await tester.tap(find.byTooltip('Close'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
    await settle(tester);
    expect(find.byType(CustomerFormScreen), findsNothing);
    expect(customerRow('Not Saved'), findsNothing);
    expect(find.text('3 customers · 3 without ID proof'), findsOneWidget);

    // Discarding also drops the draft.
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Add customer'));
    await settle(tester);
    expect(find.text('Restored what you typed earlier'), findsNothing);
    expect(fieldText(tester, fieldLabelled('Name *')), '');
  });
}
