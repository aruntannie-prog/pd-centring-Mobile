// Shared helpers for customer form tests.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sd_centring/data/file_store.dart';
import 'package:sd_centring/data/memory_repository.dart';
import 'package:sd_centring/models/customer.dart';
import 'package:sd_centring/services/media_picker.dart';
import 'package:sd_centring/services/reminder_scheduler.dart';
import 'package:sd_centring/state/app_state.dart';
import 'package:sd_centring/state/settings.dart';
import 'package:sd_centring/ui/screens/customer_form_screen.dart';
import 'package:sd_centring/ui/theme.dart';

/// A real 1x1 PNG, so Image.memory can decode it.
final Uint8List png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

class FakePicker extends MediaPicker {
  const FakePicker();

  @override
  Future<PickedMedia?> photo({required bool camera}) async =>
      PickedMedia(name: 'face.png', bytes: png, contentType: 'image/png');

  @override
  Future<PickedMedia?> documentPhoto({required bool camera}) async =>
      PickedMedia(name: 'aadhaar.png', bytes: png, contentType: 'image/png');

  @override
  Future<PickedMedia?> documentFile() async => PickedMedia(
    name: 'bill.pdf',
    bytes: Uint8List.fromList(utf8.encode('%PDF-1.4 sample')),
    contentType: 'application/pdf',
  );
}

/// Picks a PDF that is too big to upload.
class BigPicker extends FakePicker {
  const BigPicker();

  @override
  Future<PickedMedia?> documentFile() async => PickedMedia(
    name: 'huge.pdf',
    bytes: Uint8List(maxUploadBytes + 1),
    contentType: 'application/pdf',
  );
}

/// Always fails PDFs; counts every attempt.
class FailingStore extends MemoryFileStore {
  int attempts = 0;

  @override
  Future<String> upload({
    required String path,
    required Uint8List bytes,
    required String contentType,
    void Function(double progress)? onProgress,
  }) async {
    attempts++;
    if (contentType == 'application/pdf') {
      throw FileStoreException('Upload timed out.');
    }
    return super.upload(path: path, bytes: bytes, contentType: contentType);
  }
}

/// No connection for the first [failures] attempts.
class FlakyStore extends MemoryFileStore {
  FlakyStore({required this.failures});

  int failures;
  int attempts = 0;

  @override
  Future<String> upload({
    required String path,
    required Uint8List bytes,
    required String contentType,
    void Function(double progress)? onProgress,
  }) async {
    attempts++;
    if (failures > 0) {
      failures--;
      throw FileStoreException('No internet connection.', noConnection: true);
    }
    return super.upload(path: path, bytes: bytes, contentType: contentType);
  }
}

Finder inDialog(String text) => find.descendant(
  of: find.byType(AlertDialog),
  matching: find.textContaining(text),
);

Future<AppState> pumpForm(
  WidgetTester tester, {
  MemoryFileStore? files,
  Customer? existing,
  List<Customer> others = const [],
  AppState? reuse,
}) async {
  tester.view.physicalSize = const Size(420, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  MediaPicker.instance = const FakePicker();
  addTearDown(() => MediaPicker.instance = const MediaPicker());

  final settings = ReminderSettings.inMemory();
  final app =
      reuse ??
      AppState(
        repo: MemoryRepository(customers: [?existing, ...others]),
        settings: settings,
        scheduler: NoopReminderScheduler(),
        files: files ?? MemoryFileStore(),
      );
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ReminderSettings>.value(value: app.settings),
        ChangeNotifierProvider<AppState>.value(value: app),
      ],
      child: MaterialApp(
        theme: buildTheme(Brightness.light),
        home: CustomerFormScreen(existing: existing),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return app;
}
