import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/brand.dart';
import 'data/demo_data.dart';
import 'data/file_store.dart';
import 'data/firestore_repository.dart';
import 'data/memory_repository.dart';
import 'data/repository.dart';
import 'core/dates.dart';
import 'services/reminder_scheduler.dart';
import 'state/app_state.dart';
import 'state/drafts.dart';
import 'state/settings.dart';
import 'ui/screens/delivery_detail_screen.dart';
import 'ui/screens/home_shell.dart';
import 'ui/screens/login_screen.dart';
import 'ui/theme.dart';

/// Rental id from a tapped notification, waiting to be opened.
final pendingRentalId = ValueNotifier<String?>(null);

class SdApp extends StatelessWidget {
  const SdApp({
    super.key,
    required this.firebaseReady,
    required this.settings,
    required this.scheduler,
    this.drafts,
  });

  final bool firebaseReady;
  final ReminderSettings settings;
  final DraftStore? drafts;
  final ReminderScheduler scheduler;

  @override
  Widget build(BuildContext context) {
    final providers = ChangeNotifierProvider<ReminderSettings>.value(
      value: settings,
    );

    if (!firebaseReady) {
      final demo = demoData(todayDate());
      return MultiProvider(
        providers: [providers],
        child: _Session(
          key: const ValueKey('demo'),
          scheduler: scheduler,
          settings: settings,
          drafts: drafts,
          createRepo: () => MemoryRepository(
            customers: demo.customers,
            rentals: demo.rentals,
          ),
        ),
      );
    }

    // Each auth state gets its own MaterialApp, so signing out disposes every
    // open screen and listener of the previous session at once.
    return MultiProvider(
      providers: [providers],
      child: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return _materialApp(
              home: const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              ),
            );
          }
          final user = snap.data;
          if (user == null) return _materialApp(home: const LoginScreen());
          return _Session(
            key: ValueKey(user.uid),
            scheduler: scheduler,
            settings: settings,
            drafts: drafts,
            accountEmail: user.email ?? '',
            signOut: FirebaseAuth.instance.signOut,
            files: FirebaseFileStore(FirebaseStorage.instance),
            createRepo: () => FirestoreRepository(FirebaseFirestore.instance),
          );
        },
      ),
    );
  }
}

MaterialApp _materialApp({
  required Widget home,
  GlobalKey<NavigatorState>? navigatorKey,
  GlobalKey<ScaffoldMessengerState>? messengerKey,
}) => MaterialApp(
  title: Brand.appName,
  debugShowCheckedModeBanner: false,
  theme: buildTheme(Brightness.light),
  darkTheme: buildTheme(Brightness.dark),
  navigatorKey: navigatorKey,
  scaffoldMessengerKey: messengerKey,
  home: home,
);

/// Owns the data for one signed-in session (or demo mode).
class _Session extends StatefulWidget {
  const _Session({
    super.key,
    required this.scheduler,
    required this.settings,
    required this.createRepo,
    this.accountEmail,
    this.signOut,
    this.files,
    this.drafts,
  });

  final ReminderScheduler scheduler;
  final ReminderSettings settings;
  final DraftStore? drafts;
  final Repository Function() createRepo;
  final String? accountEmail;
  final Future<void> Function()? signOut;
  final FileStore? files;

  @override
  State<_Session> createState() => _SessionState();
}

class _SessionState extends State<_Session> with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  late final Repository _repo = widget.createRepo();
  late final AppState _app = AppState(
    repo: _repo,
    settings: widget.settings,
    scheduler: widget.scheduler,
    accountEmail: widget.accountEmail,
    signOut: widget.signOut,
    files: widget.files,
    drafts: widget.drafts,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _app.addListener(_onAppChanged);
    pendingRentalId.addListener(_openPending);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.scheduler.requestPermission();
      _openPending();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The date may have rolled over while the app was in the background.
    if (state == AppLifecycleState.resumed) _app.refresh();
  }

  void _onAppChanged() {
    final error = _app.takeError();
    if (error != null) {
      _messengerKey.currentState?.showSnackBar(SnackBar(content: Text(error)));
    }
    _openPending();
  }

  void _openPending() {
    final id = pendingRentalId.value;
    final nav = _navigatorKey.currentState;
    if (id == null || nav == null || !_app.loaded) return;
    pendingRentalId.value = null;
    nav.push(
      MaterialPageRoute(builder: (_) => DeliveryDetailScreen(rentalId: id)),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    pendingRentalId.removeListener(_openPending);
    _app.removeListener(_onAppChanged);
    _app.dispose();
    _repo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppState>.value(
      value: _app,
      child: _materialApp(
        home: const HomeShell(),
        navigatorKey: _navigatorKey,
        messengerKey: _messengerKey,
      ),
    );
  }
}
