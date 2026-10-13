// Delivery screens: changes made elsewhere while a screen is open, date
// limits and the quantity stepper.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sd_centring/core/dates.dart';
import 'package:sd_centring/models/rental.dart';
import 'package:sd_centring/ui/theme.dart';
import 'package:sd_centring/ui/widgets/qty_stepper.dart';

import 'flows_test.dart' show appTest, openDelivery;

Future<void> openEdit(WidgetTester tester) async {
  await openDelivery(tester, 'SD-1001');
  await tester.tap(find.byTooltip('Edit'));
  await tester.pumpAndSettle();
}

Future<void> saveForm(WidgetTester tester) async {
  await tester.tap(find.text('SAVE'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('+ never steps past a fractional maximum', (tester) async {
    final c = TextEditingController(text: '2');
    addTearDown(c.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: Scaffold(
          body: Center(child: QtyStepper(controller: c, max: 2.5)),
        ),
      ),
    );
    await tester.tap(find.byTooltip('More'));
    await tester.pump();
    expect(c.text, '2.5');
    await tester.tap(find.byTooltip('More'));
    await tester.pump();
    expect(c.text, '2.5');
  });

  appTest('editing keeps an expiry extended meanwhile', (tester, h) async {
    await openEdit(tester);
    // Another phone extends the delivery while the form is open.
    final r = h.app.rentalById('demo-r1')!;
    final extended = addDays(h.app.today, 100);
    await h.app.changeExpiry(r, extended);
    await tester.pump();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Site (optional)'),
      'Selaiyur Phase 2',
    );
    await saveForm(tester);
    final saved = h.app.rentalById('demo-r1')!;
    expect(saved.site, 'Selaiyur Phase 2');
    expect(saved.expiresOn, extended);
    expect(saved.expiryHistory, hasLength(1)); // not undone
  });

  appTest('editing checks quantities against returns recorded meanwhile', (
    tester,
    h,
  ) async {
    await openEdit(tester);
    // 15 of 40 props were returned; 20 more come back meanwhile.
    final r = h.app.rentalById('demo-r1')!;
    await h.app.addReturns(r, [
      ReturnEntry(id: 'x2', itemId: 'i2', qty: 20, date: h.app.today),
    ]);
    await tester.pump();

    await tester.enterText(find.byKey(const ValueKey('item-qty-1')), '30');
    await saveForm(tester);
    expect(find.textContaining('35 already returned'), findsOneWidget);
    expect(h.app.rentalById('demo-r1')!.items[1].qty, 40);
  });

  appTest('editing a delivery deleted meanwhile does not bring it back', (
    tester,
    h,
  ) async {
    await openEdit(tester);
    await h.app.deleteRental('demo-r1');
    await tester.pump();
    await saveForm(tester);
    expect(find.text('This delivery was deleted on another phone.'), findsOne);
    expect(h.app.rentalById('demo-r1'), isNull);
  });

  appTest('delivery date cannot move after the first return', (
    tester,
    h,
  ) async {
    // SD-1001 was delivered 34 days ago; 15 props came back 6 days ago.
    await openEdit(tester);
    await tester.tap(find.text('Delivered on'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Switch to input'));
    await tester.pumpAndSettle();
    final d = addDays(h.app.today, -1);
    final typed =
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.day.toString().padLeft(2, '0')}/${d.year}';
    await tester.enterText(find.byType(TextField).last, typed);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await saveForm(tester);
    expect(
      find.textContaining('cannot be after the first return'),
      findsOneWidget,
    );
    expect(h.app.rentalById('demo-r1')!.issuedOn, addDays(h.app.today, -34));
  });

  appTest('expiry picker opens for a delivery extended years ahead', (
    tester,
    h,
  ) async {
    final r = h.app.rentalById('demo-r1')!;
    await h.app.saveRental(
      r.copyWith(expiresOn: addDays(r.issuedOn, 365 * 3 + 200)),
    );
    await tester.pump();
    await openEdit(tester);
    await tester.tap(find.text('Expires on'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(DatePickerDialog), findsOneWidget);
  });
}
