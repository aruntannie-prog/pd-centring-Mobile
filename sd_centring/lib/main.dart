import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'services/reminder_scheduler.dart';
import 'state/drafts.dart';
import 'state/settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Until `flutterfire configure` generates real options, the app runs in
  // demo mode instead of crashing.
  var firebaseReady = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    firebaseReady = true;
    if (kIsWeb) {
      // Browsers keep nothing by default: without this, changes made
      // offline are lost when the tab is closed.
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
      );
    }
  } catch (e) {
    debugPrint('Firebase not configured, starting in demo mode: $e');
  }

  final settings = await ReminderSettings.load();
  final drafts = await DraftStore.load();
  final scheduler = ReminderScheduler.forPlatform();
  await scheduler.init(onOpenRental: (id) => pendingRentalId.value = id);
  final launchedFrom = await scheduler.launchRentalId();
  if (launchedFrom != null) pendingRentalId.value = launchedFrom;

  runApp(
    SdApp(
      firebaseReady: firebaseReady,
      settings: settings,
      drafts: drafts,
      scheduler: scheduler,
    ),
  );
}
