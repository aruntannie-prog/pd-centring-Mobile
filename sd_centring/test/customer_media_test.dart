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

class FailingStore extends MemoryFileStore {
  @override
  Future<String> upload({
    required String path,
    required Uint8List bytes,
    required String contentType,
    void Function(double progress)? onProgress,
  }) async {
    if (contentType == 'application/pdf') {
      throw FileStoreException('Upload timed out.');
    }
    return super.upload(path: path, bytes: bytes, contentType: contentType);
  }
}

Future<AppState> pumpForm(
  WidgetTester tester, {
  MemoryFileStore? files,
  Customer? existing,
}) async {
  tester.view.physicalSize = const Size(420, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  MediaPicker.instance = const FakePicker();
  addTearDown(() => MediaPicker.instance = const MediaPicker());

  final settings = ReminderSettings.inMemory();
  final app = AppState(
    repo: MemoryRepository(customers: [?existing]),
    settings: settings,
    scheduler: NoopReminderScheduler(),
    files: files ?? MemoryFileStore(),
  );
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ReminderSettings>.value(value: settings),
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

void main() {
  test('photo and documents survive the storage round trip', () {
    final c = Customer(
      id: 'c',
      name: 'Ravi',
      phone: '9123456780',
      referredBy: 'Murugan',
      photoUrl: 'https://example.test/p.jpg',
      documents: [
        CustomerDoc(
          id: 'd1',
          kind: 'Aadhaar',
          fileName: 'a.jpg',
          url: 'https://example.test/a.jpg',
          contentType: 'image/jpeg',
          sizeBytes: 1234,
          uploadedAt: DateTime(2026, 10, 1),
        ),
      ],
      createdAt: DateTime(2026),
    );
    final back = Customer.fromMap('c', c.toMap());
    expect(back.photoUrl, c.photoUrl);
    expect(back.referredBy, 'Murugan');
    expect(back.documents.single.kind, 'Aadhaar');
    expect(back.documents.single.sizeBytes, 1234);
    // Broken entries are skipped rather than crashing the list.
    final messy = Customer.fromMap('c', {
      'name': 'X',
      'documents': [
        {
          'id': 'ok',
          'url': 'https://x/y.pdf',
          'contentType': 'application/pdf',
        },
        {'id': 'no-url'},
        'junk',
      ],
    });
    expect(messy.documents.single.id, 'ok');
    expect(messy.documents.single.isPdf, isTrue);
  });

  testWidgets('add photo and documents, then save', (tester) async {
    final files = MemoryFileStore();
    final app = await pumpForm(tester, files: files);

    expect(find.text('Add photo'), findsOneWidget);
    await tester.tap(find.text('Add photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose from gallery'));
    await tester.pumpAndSettle();
    expect(find.text('Add photo'), findsNothing);

    await tester.tap(find.text('Take photo').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upload file'));
    await tester.pumpAndSettle();
    expect(find.textContaining('aadhaar.png'), findsOneWidget);
    expect(find.textContaining('bill.pdf'), findsOneWidget);
    // First document defaults to Aadhaar, the next to PAN.
    expect(find.text('Aadhaar'), findsOneWidget);
    expect(find.text('PAN'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name *'),
      'Selvam',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Phone *'),
      '9000011111',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Referred by'),
      'Murugan',
    );
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 50));

    final saved = app.customers.single;
    expect(saved.photoUrl, startsWith('memory://'));
    expect(saved.referredBy, 'Murugan');
    expect(saved.documents.map((d) => d.kind), ['Aadhaar', 'PAN']);
    expect(saved.documents.last.isPdf, isTrue);
    expect(files.count, 3);

    await tester.pumpWidget(const SizedBox());
    app.dispose();
  });

  testWidgets('a failed upload is reported and the rest is saved', (
    tester,
  ) async {
    final app = await pumpForm(tester, files: FailingStore());
    await tester.tap(find.text('Upload file'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name *'),
      'Selvam',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Phone *'),
      '9000011111',
    );
    await tester.tap(find.text('SAVE'));
    // The upload progress bar keeps animating behind the dialog.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Saved, but some files did not upload'), findsOneWidget);
    expect(find.textContaining('Upload timed out.'), findsOneWidget);
    expect(app.customers.single.documents, isEmpty);
    await tester.tap(find.text('OK'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox());
    app.dispose();
  });

  testWidgets('removing a document deletes its file on save', (tester) async {
    final files = MemoryFileStore();
    final url = await files.upload(
      path: 'customers/c/docs/d1.png',
      bytes: png,
      contentType: 'image/png',
    );
    final existing = Customer(
      id: 'c',
      name: 'Ravi',
      phone: '9123456780',
      documents: [
        CustomerDoc(
          id: 'd1',
          kind: 'Voter ID',
          fileName: 'v.png',
          url: url,
          contentType: 'image/png',
          sizeBytes: png.length,
          uploadedAt: DateTime(2026),
        ),
      ],
      createdAt: DateTime(2026),
    );
    final app = await pumpForm(tester, files: files, existing: existing);
    expect(find.text('Voter ID'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove document'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 50));

    expect(app.customerById('c')!.documents, isEmpty);
    expect(files.count, 0);
    await tester.pumpWidget(const SizedBox());
    app.dispose();
  });
}
