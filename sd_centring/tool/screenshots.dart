// Renders one screen with demo data, chosen by the URL (?s=<name>), so the
// README screenshots can be regenerated. Not part of the app.
//
//   flutter build web -t tool/screenshots.dart --no-web-resources-cdn
//   then open index.html?s=alerts (see list below)

// A dev tool: demo-only settings and fire-and-forget navigation are fine here.
// ignore_for_file: invalid_use_of_visible_for_testing_member, use_build_context_synchronously
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sd_centring/core/dates.dart';
import 'package:sd_centring/data/demo_data.dart';
import 'package:sd_centring/data/memory_repository.dart';
import 'package:sd_centring/data/repository.dart';
import 'package:sd_centring/domain/whatsapp.dart';
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

void main() {
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
    }
  });
}
