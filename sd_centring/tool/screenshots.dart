// Renders one screen with demo data, chosen by the URL (?s=<name>), so the
// README screenshots can be regenerated. Not part of the app.
//
//   flutter build web -t tool/screenshots.dart --no-web-resources-cdn
//   then open index.html?s=alerts (see list below)

// A dev tool: demo-only settings and fire-and-forget navigation are fine here.
// ignore_for_file: invalid_use_of_visible_for_testing_member, use_build_context_synchronously
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sd_centring/core/dates.dart';
import 'package:sd_centring/data/demo_data.dart';
import 'package:sd_centring/data/memory_repository.dart';
import 'package:sd_centring/data/repository.dart';
import 'package:sd_centring/domain/whatsapp.dart';
import 'package:sd_centring/models/customer.dart';
import 'package:sd_centring/models/rental.dart';
import 'package:sd_centring/services/reminder_scheduler.dart';
import 'package:sd_centring/state/app_state.dart';
import 'package:sd_centring/state/settings.dart';
import 'package:sd_centring/ui/screens/customer_detail_screen.dart';
import 'package:sd_centring/ui/screens/customer_form_screen.dart';
import 'package:sd_centring/ui/screens/customer_picker.dart';
import 'package:sd_centring/ui/screens/delivery_detail_screen.dart';
import 'package:sd_centring/ui/screens/delivery_form_screen.dart';
import 'package:sd_centring/ui/screens/home_shell.dart';
import 'package:sd_centring/ui/screens/login_screen.dart';
import 'package:sd_centring/ui/screens/record_return_sheet.dart';
import 'package:sd_centring/ui/screens/whatsapp_sheet.dart';
import 'package:sd_centring/ui/theme.dart';

class _Repo extends MemoryRepository {
  _Repo({
    super.customers,
    super.rentals,
    this.state = SyncState.demo,
    this.fail = false,
  });
  final SyncState state;
  final bool fail;
  @override
  bool get isDemo => state == SyncState.demo;
  @override
  ValueListenable<SyncState> get sync => ValueNotifier(state);
  @override
  Stream<List<Rental>> watchRentals() =>
      fail ? Stream.error('permission-denied') : super.watchRentals();
}

/// Draws a fake ID card so screenshots can show a document thumbnail.
Future<Uint8List> _sampleCard() async {
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  const w = 640.0, h = 400.0;
  c.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, w, h),
      const Radius.circular(24),
    ),
    Paint()..color = const Color(0xFFEFF4FA),
  );
  c.drawRect(
    const Rect.fromLTWH(0, 0, w, 70),
    Paint()..color = const Color(0xFF2F6FED),
  );
  c.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(40, 110, 150, 190),
      const Radius.circular(12),
    ),
    Paint()..color = const Color(0xFFB8C6DB),
  );
  final line = Paint()..color = const Color(0xFF9AA9BF);
  for (var i = 0; i < 5; i++) {
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(220, 120.0 + i * 36, i.isEven ? 340 : 260, 16),
        const Radius.circular(8),
      ),
      line,
    );
  }
  final img = await rec.endRecording().toImage(w.toInt(), h.toInt());
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final q = Uri.base.queryParameters;
  final screen = q['s'] ?? 'alerts';
  final dark = q['theme'] == 'dark';
  final demo = demoData(todayDate());
  final repo = _Repo(
    customers: screen == 'empty' ? const [] : demo.customers,
    rentals: screen == 'empty' ? const [] : demo.rentals,
    state: switch (screen) {
      'offline' => SyncState.offline,
      'pending' => SyncState.pending,
      'error' => SyncState.synced,
      _ => SyncState.demo,
    },
    fail: screen == 'error',
  );
  final settings = ReminderSettings.inMemory();
  final app = AppState(
    repo: repo,
    settings: settings,
    scheduler: NoopReminderScheduler(),
    accountEmail: 'owner@sdcentring.in',
    signOut: (screen == 'settings') ? () async {} : null,
  );
  if (screen == 'customer' || screen == 'editcustomer') {
    final card = await _sampleCard();
    final url = await app.files.upload(
      path: 'customers/demo-c1/docs/a.png',
      bytes: card,
      contentType: 'image/png',
    );
    final pdf = await app.files.upload(
      path: 'customers/demo-c1/docs/b.pdf',
      bytes: Uint8List.fromList([37, 80, 68, 70]),
      contentType: 'application/pdf',
    );
    final c1 = demo.customers.first;
    await repo.saveCustomer(
      c1.copyWith(
        referredBy: 'Lakshmi Constructions',
        documents: [
          CustomerDoc(
            id: 'd1',
            kind: 'Aadhaar',
            fileName: 'aadhaar_front.png',
            url: url,
            contentType: 'image/png',
            sizeBytes: card.length,
            uploadedAt: DateTime.now(),
          ),
          CustomerDoc(
            id: 'd2',
            kind: 'Utility bill',
            fileName: 'eb_bill_sep.pdf',
            url: pdf,
            contentType: 'application/pdf',
            sizeBytes: 182000,
            uploadedAt: DateTime.now(),
          ),
        ],
      ),
    );
  }
  final nav = GlobalKey<NavigatorState>();

  final tab = switch (screen) {
    'deliveries' => 1,
    'customers' => 2,
    'settings' => 3,
    _ => 0,
  };

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ReminderSettings>.value(value: settings),
        ChangeNotifierProvider<AppState>.value(value: app),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        navigatorKey: nav,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        home: screen == 'login'
            ? const LoginScreen()
            : HomeShell(initialIndex: tab),
      ),
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final n = nav.currentState!;
    Future<void> push(Widget w, {bool dialog = false}) async {
      n.push(MaterialPageRoute(fullscreenDialog: dialog, builder: (_) => w));
      await Future<void>.delayed(const Duration(milliseconds: 600));
    }

    final r1 = app.rentalById('demo-r1');
    switch (screen) {
      case 'detail':
        await push(const DeliveryDetailScreen(rentalId: 'demo-r1'));
      case 'returned':
        await push(const DeliveryDetailScreen(rentalId: 'demo-r5'));
      case 'return':
        await push(const DeliveryDetailScreen(rentalId: 'demo-r1'));
        RecordReturnSheet.show(n.overlay!.context, r1!);
      case 'extend':
        await push(const DeliveryDetailScreen(rentalId: 'demo-r1'));
        showDatePicker(
          context: n.overlay!.context,
          helpText: 'New expiry date',
          initialDate: r1!.expiresOn,
          firstDate: r1.issuedOn,
          lastDate: addDays(r1.expiresOn, 365),
        );
      case 'whatsapp':
        await push(const DeliveryDetailScreen(rentalId: 'demo-r1'));
        WhatsAppSheet.show(
          n.overlay!.context,
          r1!,
          whatsAppNumber('9840012345')!,
        );
      case 'new':
        await push(const DeliveryFormScreen(), dialog: true);
      case 'edit':
        await push(DeliveryFormScreen(existing: r1), dialog: true);
      case 'picker':
        await push(const DeliveryFormScreen(), dialog: true);
        CustomerPicker.show(n.overlay!.context);
      case 'customer':
        await push(const CustomerDetailScreen(customerId: 'demo-c1'));
      case 'newcustomer':
        await push(const CustomerFormScreen(), dialog: true);
      case 'editcustomer':
        await push(
          CustomerFormScreen(existing: app.customerById('demo-c1')),
          dialog: true,
        );
    }
  });
}
