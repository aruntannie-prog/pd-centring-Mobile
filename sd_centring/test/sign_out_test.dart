// Signing out: reminders are cleared, and changes still waiting to upload
// are pointed out first (they only upload when the same person signs in
// again on this phone).
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sd_centring/data/memory_repository.dart';
import 'package:sd_centring/data/repository.dart';
import 'package:sd_centring/domain/reminders.dart';
import 'package:sd_centring/services/reminder_scheduler.dart';
import 'package:sd_centring/state/app_state.dart';
import 'package:sd_centring/state/settings.dart';
import 'package:sd_centring/ui/screens/settings_screen.dart';
import 'package:sd_centring/ui/theme.dart';

class CloudRepo extends MemoryRepository {
  final state = ValueNotifier<SyncState>(SyncState.synced);
  @override
  bool get isDemo => false;
  @override
  ValueListenable<SyncState> get sync => state;
}

class RecordingScheduler extends NoopReminderScheduler {
  final applied = <List<PlannedReminder>>[];
  @override
  Future<void> apply(List<PlannedReminder> plan) async {
    applied.add(plan);
    await super.apply(plan);
  }
}

void main() {
  late CloudRepo repo;
  late RecordingScheduler scheduler;
  late AppState app;
  late int signOuts;

  Future<void> pumpSettings(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    repo = CloudRepo();
    scheduler = RecordingScheduler();
    signOuts = 0;
    app = AppState(
      repo: repo,
      settings: ReminderSettings.inMemory(),
      scheduler: scheduler,
      accountEmail: 'staff@sd.example',
      signOut: () async => signOuts++,
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ReminderSettings>.value(value: app.settings),
          ChangeNotifierProvider<AppState>.value(value: app),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: const Scaffold(body: SettingsScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapSignOut(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('Sign out'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the signed-in account', (tester) async {
    await pumpSettings(tester);
    expect(find.textContaining('staff@sd.example'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    app.dispose();
  });

  testWidgets('all saved: a plain confirmation, then reminders cleared', (
    tester,
  ) async {
    await pumpSettings(tester);
    await tapSignOut(tester);
    expect(find.text('Sign out?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
    await tester.pumpAndSettle();
    expect(signOuts, 1);
    expect(scheduler.applied.last, isEmpty);
    await tester.pumpWidget(const SizedBox());
    app.dispose();
  });

  testWidgets('changes waiting to upload are pointed out first', (
    tester,
  ) async {
    await pumpSettings(tester);
    repo.state.value = SyncState.pending;
    await tester.pump();
    await tapSignOut(tester);
    expect(find.text('Changes not uploaded yet'), findsOneWidget);
    // Staying signed in is the safe default.
    await tester.tap(find.text('Stay signed in'));
    await tester.pumpAndSettle();
    expect(signOuts, 0);

    await tapSignOut(tester);
    await tester.tap(find.text('Sign out anyway'));
    await tester.pumpAndSettle();
    expect(signOuts, 1);
    await tester.pumpWidget(const SizedBox());
    app.dispose();
  });

  testWidgets('a customer not yet in the cloud also counts as unsent', (
    tester,
  ) async {
    await pumpSettings(tester);
    repo.pendingCustomers.value = {'c1'};
    await tester.pump();
    await tapSignOut(tester);
    expect(find.text('Changes not uploaded yet'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    app.dispose();
  });
}
