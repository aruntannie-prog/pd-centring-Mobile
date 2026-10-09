import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sd_centring/core/dates.dart';
import 'package:sd_centring/data/demo_data.dart';
import 'package:sd_centring/data/memory_repository.dart';
import 'package:sd_centring/domain/expiry.dart';
import 'package:sd_centring/domain/whatsapp.dart';
import 'package:sd_centring/models/customer.dart';
import 'package:sd_centring/models/rental.dart';
import 'package:sd_centring/services/reminder_scheduler.dart';
import 'package:sd_centring/state/app_state.dart';
import 'package:sd_centring/state/settings.dart';
import 'package:sd_centring/ui/screens/delivery_detail_screen.dart';
import 'package:sd_centring/ui/screens/whatsapp_sheet.dart';
import 'package:sd_centring/ui/theme.dart';

void main() {
  group('whatsAppNumber', () {
    test('accepts common Indian formats', () {
      expect(whatsAppNumber('9840012345'), '919840012345');
      expect(whatsAppNumber('98400 12345'), '919840012345');
      expect(whatsAppNumber('098400-12345'), '919840012345');
      expect(whatsAppNumber('+91 98400 12345'), '919840012345');
      expect(whatsAppNumber('919840012345'), '919840012345');
      expect(whatsAppNumber('0091 98400 12345'), '919840012345');
    });

    test('keeps other countries when written with +', () {
      expect(whatsAppNumber('+971 50 123 4567'), '971501234567');
    });

    test('rejects numbers that cannot be right', () {
      expect(whatsAppNumber(''), isNull);
      expect(whatsAppNumber('12345'), isNull);
      expect(whatsAppNumber('044 2345'), isNull);
      expect(whatsAppNumber('abc'), isNull);
    });
  });

  group('message', () {
    final today = DateTime(2026, 10, 9);
    Rental rental(int expiresIn, {String site = 'Selaiyur'}) => Rental(
      id: 'r',
      dcNumber: 'SD-1001',
      customerId: 'c',
      customerName: 'Murugan',
      site: site,
      issuedOn: addDays(today, -30),
      expiresOn: addDays(today, expiresIn),
      items: const [
        RentalItem(id: 'a', name: 'Props', qty: 40),
        RentalItem(id: 'b', name: 'Palagai', qty: 12.5, unit: 'ft'),
      ],
      returns: [ReturnEntry(id: 'x', itemId: 'a', qty: 15, date: today)],
      createdAt: today,
      updatedAt: today,
    );
    String msg(Rental r) => expiryMessage(
      r,
      customerName: 'Murugan',
      info: expiryOf(r, today: today, soonDays: 3),
    );

    test('expired', () {
      final m = msg(rental(-4));
      expect(m, startsWith('Hello Murugan,'));
      expect(
        m,
        contains('DC SD-1001 at Selaiyur ended on 5 Oct 2026 (4 days overdue)'),
      );
      expect(m, contains('• Props: 25 pcs'));
      expect(m, contains('• Palagai: 12.5 ft'));
      expect(m, contains('SD Centring'));
    });

    test('today and upcoming', () {
      expect(msg(rental(0)), contains('ends today (9 Oct 2026)'));
      expect(
        msg(rental(2, site: '')),
        contains('DC SD-1001 ends on 11 Oct 2026 (2 days left)'),
      );
    });

    test('never mentions money', () {
      final m = msg(rental(-4)).toLowerCase();
      for (final word in ['₹', 'rs', 'amount', 'rate', 'gst', 'total']) {
        expect(RegExp('\\b$word\\b').hasMatch(m), isFalse, reason: word);
      }
    });

    test('link encodes spaces and new lines safely', () {
      final link = whatsAppLink(
        '919840012345',
        'Hello A,\nLine 2 & more',
      ).toString();
      expect(link, startsWith('https://wa.me/919840012345?text='));
      expect(link, contains('Hello%20A%2C%0ALine%202%20%26%20more'));
      expect(link, isNot(contains('+')));
    });
  });

  group('WhatsApp button', () {
    Future<AppState> pumpDetail(
      WidgetTester tester, {
      String phone = '9840012345',
    }) async {
      final demo = demoData(todayDate());
      final customers = [
        for (final c in demo.customers)
          c.id == 'demo-c1' ? c.copyWith(phone: phone) : c,
      ];
      final settings = ReminderSettings.inMemory();
      final app = AppState(
        repo: MemoryRepository(customers: customers, rentals: demo.rentals),
        settings: settings,
        scheduler: NoopReminderScheduler(),
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ReminderSettings>.value(value: settings),
            ChangeNotifierProvider<AppState>.value(value: app),
          ],
          child: MaterialApp(
            theme: buildTheme(Brightness.light),
            home: const DeliveryDetailScreen(rentalId: 'demo-r1'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return app;
    }

    testWidgets('previews the message, opens WhatsApp and records it', (
      tester,
    ) async {
      Uri? opened;
      WhatsAppSheet.opener = (uri) async {
        opened = uri;
        return true;
      };
      addTearDown(() => WhatsAppSheet.opener = (uri) async => false);

      final app = await pumpDetail(tester);
      await tester.tap(find.text('Send WhatsApp reminder'));
      await tester.pumpAndSettle();
      expect(find.text('To Murugan Builders · +919840012345'), findsOneWidget);
      expect(find.textContaining('4 days overdue'), findsWidgets);

      await tester.tap(find.text('Open WhatsApp'));
      await tester.pumpAndSettle();
      expect(
        opened.toString(),
        startsWith(
          'https://wa.me/919840012345?text=Hello%20Murugan%20Builders',
        ),
      );
      expect(app.rentalById('demo-r1')!.lastMessagedAt, isNotNull);
      expect(find.textContaining('Last WhatsApp reminder'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      app.dispose();
    });

    testWidgets('explains when WhatsApp cannot open', (tester) async {
      WhatsAppSheet.opener = (uri) async => false;
      final app = await pumpDetail(tester);
      await tester.tap(find.text('Send WhatsApp reminder'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open WhatsApp'));
      await tester.pumpAndSettle();
      expect(
        find.text('WhatsApp could not be opened on this device'),
        findsOneWidget,
      );
      expect(app.rentalById('demo-r1')!.lastMessagedAt, isNull);
      await tester.pumpWidget(const SizedBox());
      app.dispose();
    });

    testWidgets('disabled without a valid mobile number', (tester) async {
      final app = await pumpDetail(tester, phone: '2345');
      final button = tester.widget<OutlinedButton>(
        find.ancestor(
          of: find.text('Send WhatsApp reminder'),
          matching: find.byType(OutlinedButton),
        ),
      );
      expect(button.onPressed, isNull);
      expect(find.textContaining('Add a valid mobile number'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      app.dispose();
    });
  });

  test('lastMessagedAt survives storage round trip', () {
    final r = Rental(
      id: 'r',
      dcNumber: 'SD-1',
      customerId: 'c',
      customerName: 'A',
      issuedOn: DateTime(2026, 10, 1),
      expiresOn: DateTime(2026, 10, 9),
      items: const [RentalItem(id: 'a', name: 'Props', qty: 1)],
      lastMessagedAt: DateTime(2026, 10, 9, 10, 30),
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final back = Rental.tryFromMap('r', r.toMap())!;
    expect(back.lastMessagedAt, DateTime(2026, 10, 9, 10, 30));
    expect(
      Rental.tryFromMap('r', {
        ...r.toMap(),
        'lastMessagedAt': null,
      })!.lastMessagedAt,
      isNull,
    );
    expect(Customer.fromMap('c', const {}).name, '');
  });
}
