import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sd_centring/data/file_store.dart';
import 'package:sd_centring/models/customer.dart';
import 'package:sd_centring/ui/screens/customer_form_screen.dart';

import 'support.dart';

void main() {
  test('photo and documents survive the storage round trip', () {
    final c = Customer(
      id: 'c',
      name: 'Ravi',
      phone: '9123456780',
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
    // SD keeps no referral details.
    expect(c.toMap().containsKey('referredBy'), isFalse);
    expect(back.photoUrl, c.photoUrl);
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
    expect(find.textContaining('Referred'), findsNothing);
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
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 50));

    final saved = app.customers.single;
    expect(saved.photoUrl, startsWith('memory://'));
    expect(saved.documents.map((d) => d.kind), ['Aadhaar', 'PAN']);
    expect(saved.documents.last.isPdf, isTrue);
    expect(files.count, 3);

    await tester.pumpWidget(const SizedBox());
    app.dispose();
  });

  testWidgets('a failed upload keeps the form open until the user decides', (
    tester,
  ) async {
    final store = FailingStore();
    final app = await pumpForm(tester, files: store);
    await tester.tap(find.text('Take photo').last);
    await tester.pumpAndSettle();
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
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('1 file did not upload'), findsOneWidget);
    expect(inDialog('Upload timed out.'), findsOneWidget);
    expect(inDialog('not saved yet'), findsOneWidget);
    // Nothing is written until the user chooses.
    expect(app.customers, isEmpty);

    // Keep editing: the form stays, the failed file is marked.
    await tester.tap(find.text('Keep editing'));
    await tester.pump(const Duration(seconds: 1));
    expect(
      find.textContaining('Not uploaded: Upload timed out.'),
      findsOneWidget,
    );
    expect(find.textContaining('aadhaar.png'), findsOneWidget);

    // Save without the failed file: the uploaded image is not uploaded again.
    await tester.tap(find.text('SAVE'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Save without them'));
    await tester.pump(const Duration(seconds: 1));
    final saved = app.customers.single;
    expect(saved.documents.single.kind, 'Aadhaar');
    expect(store.count, 1);
    expect(store.attempts, 3); // image once, PDF twice
    await tester.pumpWidget(const SizedBox());
    app.dispose();
  });

  testWidgets('try again uploads the file once the connection is back', (
    tester,
  ) async {
    final store = FlakyStore(failures: 1);
    final app = await pumpForm(tester, files: store);
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
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(inDialog('No internet connection'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(app.customers.single.documents.single.isPdf, isTrue);
    expect(store.count, 1);
    await tester.pumpWidget(const SizedBox());
    app.dispose();
  });

  testWidgets('after a connection failure the other files are not tried', (
    tester,
  ) async {
    final store = FlakyStore(failures: 100);
    final app = await pumpForm(tester, files: store);
    await tester.tap(find.text('Add photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose from gallery'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take photo').last);
    await tester.pumpAndSettle();
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
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('3 files did not upload'), findsOneWidget);
    expect(store.attempts, 1);
    await tester.tap(find.text('Save without them'));
    await tester.pump(const Duration(seconds: 1));
    final saved = app.customers.single;
    expect(saved.photoUrl, isEmpty);
    expect(saved.documents, isEmpty);
    await tester.pumpWidget(const SizedBox());
    app.dispose();
  });

  testWidgets('discarding the form deletes files it already uploaded', (
    tester,
  ) async {
    final store = FailingStore();
    final app = await pumpForm(tester, files: store);
    await tester.tap(find.text('Take photo').last);
    await tester.pumpAndSettle();
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
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Keep editing'));
    await tester.pump(const Duration(seconds: 1));
    expect(store.count, 1);

    await tester.tap(find.byType(CloseButton));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Discard this customer?'), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await tester.pump(const Duration(seconds: 1));
    expect(store.count, 0);
    expect(app.customers, isEmpty);
    expect(app.drafts.read(newCustomerDraftKey), isNull);
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
