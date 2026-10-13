// Reading the name and address from uploaded ID / address proofs.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sd_centring/models/customer.dart';
import 'package:sd_centring/services/document_reader.dart';

import 'support.dart';

Finder field(String label) => find.widgetWithText(TextFormField, label);

String text(WidgetTester tester, String label) => tester
    .widget<TextField>(
      find.descendant(of: field(label), matching: find.byType(TextField)),
    )
    .controller!
    .text;

Future<void> addPdf(WidgetTester tester) async {
  await tester.tap(find.text('Upload file'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  group('reply parsing', () {
    test('reads a clean reply', () {
      final d = parseDocumentDetails(
        '{"kind":"Aadhaar","name":"Ravi Kumar",'
        '"address":"12, Gandhi Street, Tambaram, Chennai 600045"}',
      );
      expect(d.kind, 'Aadhaar');
      expect(d.name, 'Ravi Kumar');
      expect(d.address, '12, Gandhi Street, Tambaram, Chennai 600045');
    });

    test('missing fields stay empty (PAN has no address)', () {
      final d = parseDocumentDetails('{"kind":"PAN","name":"RAVI KUMAR"}');
      expect(d.name, 'Ravi Kumar');
      expect(d.address, isEmpty);
      expect(d.isEmpty, isFalse);
    });

    test('tolerates code fences, wrong types and unknown kinds', () {
      final d = parseDocumentDetails(
        '```json\n{"kind":"Passport","name":42,"address":"Chennai"}\n```',
      );
      expect(d.kind, isEmpty);
      expect(d.name, isEmpty);
      expect(d.address, 'Chennai');
    });

    test('junk is reported, not crashed on', () {
      expect(
        () => parseDocumentDetails('sorry, I cannot read that'),
        throwsA(isA<DocumentReadException>()),
      );
      expect(
        () => parseDocumentDetails('[1,2]'),
        throwsA(isA<DocumentReadException>()),
      );
    });

    test('names in capitals become readable, initials stay', () {
      expect(tidyPersonName('RAVI  KUMAR'), 'Ravi Kumar');
      expect(tidyPersonName('R. SELVAM'), 'R. Selvam');
      expect(tidyPersonName('Ravi kumar'), 'Ravi kumar'); // kept as printed
      expect(tidyPersonName(''), '');
    });

    test('addresses become one tidy line', () {
      expect(
        tidyAddress('12, Gandhi Street,\nTambaram ,, Chennai\n- 600045 '),
        '12, Gandhi Street, Tambaram, Chennai, - 600045',
      );
      expect(tidyAddress(' , '), '');
    });

    test('the prompt never asks for ID numbers to be returned', () {
      expect(documentPrompt, contains('Never return ID numbers'));
      expect(documentPrompt, contains('S/O'));
    });
  });

  group('password-protected PDFs', () {
    test('are recognised and explained', () {
      final locked = Uint8List.fromList(
        utf8.encode('%PDF-1.7\n1 0 obj\ntrailer << /Encrypt 5 0 R >>'),
      );
      final open = Uint8List.fromList(utf8.encode('%PDF-1.7\n1 0 obj\n'));
      expect(isEncryptedPdf(locked), isTrue);
      expect(isEncryptedPdf(open), isFalse);
      expect(
        () => checkReadable(locked, 'application/pdf'),
        throwsA(
          isA<DocumentReadException>().having(
            (e) => e.message,
            'message',
            contains('password-protected'),
          ),
        ),
      );
      // Images are never treated as PDFs.
      checkReadable(locked, 'image/png');
    });
  });

  group('in the form', () {
    testWidgets('fills empty name and address and sets the type', (
      tester,
    ) async {
      final reader = FakeReader(
        const DocumentDetails(
          kind: 'Utility bill',
          name: 'Selvam Kumar',
          address: '4, Lake View Road, Selaiyur, Chennai 600073',
        ),
      );
      final app = await pumpForm(tester, reader: reader);
      await addPdf(tester);

      expect(reader.calls, 1);
      expect(text(tester, 'Name *'), 'Selvam Kumar');
      expect(
        text(tester, 'Address'),
        '4, Lake View Road, Selaiyur, Chennai 600073',
      );
      expect(
        find.text('Filled name and address from Utility bill'),
        findsOneWidget,
      );
      expect(find.text('From Utility bill. Please check.'), findsNWidgets(2));
      expect(find.text('Utility bill'), findsOneWidget); // the row's type

      await tester.enterText(field('Phone *'), '9000011111');
      await tester.tap(find.text('SAVE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final c = app.customers.single;
      expect(c.name, 'Selvam Kumar');
      expect(c.address, '4, Lake View Road, Selaiyur, Chennai 600073');
      expect(c.documents.single.kind, 'Utility bill');
      await tester.pumpWidget(const SizedBox());
      app.dispose();
    });

    testWidgets('a document without an address leaves the address blank', (
      tester,
    ) async {
      final reader = FakeReader(
        const DocumentDetails(kind: 'PAN', name: 'Ravi Kumar'),
      );
      final app = await pumpForm(tester, reader: reader);
      await addPdf(tester);
      expect(text(tester, 'Name *'), 'Ravi Kumar');
      expect(text(tester, 'Address'), isEmpty);
      expect(find.text('Filled name from PAN'), findsOneWidget);
      expect(find.textContaining('has no address'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      app.dispose();
    });

    testWidgets('typed details are never overwritten; the document value '
        'is offered instead', (tester) async {
      final reader = FakeReader(
        const DocumentDetails(
          kind: 'Aadhaar',
          name: 'Selvam Kumar',
          address: '12, Gandhi Street, Chennai',
        ),
      );
      final app = await pumpForm(tester, reader: reader);
      await tester.enterText(field('Name *'), 'Selvam');
      await addPdf(tester);

      expect(text(tester, 'Name *'), 'Selvam');
      expect(text(tester, 'Address'), '12, Gandhi Street, Chennai');
      expect(find.text('Name on document: '), findsNothing); // rich text
      expect(find.textContaining('Selvam Kumar'), findsOneWidget);
      await tester.tap(find.text('Use'));
      await tester.pump();
      expect(text(tester, 'Name *'), 'Selvam Kumar');
      expect(find.text('Use'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      app.dispose();
    });

    testWidgets('the same name in different case is not offered', (
      tester,
    ) async {
      final reader = FakeReader(
        const DocumentDetails(kind: 'Aadhaar', name: 'Selvam Kumar'),
      );
      final app = await pumpForm(tester, reader: reader);
      await tester.enterText(field('Name *'), 'SELVAM KUMAR');
      await addPdf(tester);
      expect(find.text('Use'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      app.dispose();
    });

    testWidgets('a failure is explained and does not block saving', (
      tester,
    ) async {
      final reader = FakeReader(
        const DocumentDetails(),
        error: 'This PDF is password-protected.',
      );
      final app = await pumpForm(tester, reader: reader);
      await addPdf(tester);
      expect(find.text('Could not read the details'), findsOneWidget);
      expect(find.text('This PDF is password-protected.'), findsOneWidget);

      await tester.enterText(field('Name *'), 'Selvam');
      await tester.enterText(field('Phone *'), '9000011111');
      await tester.tap(find.text('SAVE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(app.customers.single.documents, hasLength(1));
      await tester.pumpWidget(const SizedBox());
      app.dispose();
    });

    testWidgets('nothing found is said plainly', (tester) async {
      final app = await pumpForm(
        tester,
        reader: FakeReader(const DocumentDetails(kind: 'Other')),
      );
      await addPdf(tester);
      expect(find.text('No name or address found on this Other'), findsOne);
      await tester.pumpWidget(const SizedBox());
      app.dispose();
    });

    testWidgets('a type chosen by hand is kept', (tester) async {
      final gate = Completer<void>();
      final reader = FakeReader(
        const DocumentDetails(kind: 'Aadhaar', name: 'Ravi'),
        gate: gate,
      );
      final app = await pumpForm(tester, reader: reader);
      await addPdf(tester);
      expect(find.text('Reading name and address…'), findsOneWidget);
      // The reading spinner keeps animating, so pump for fixed times.
      await tester.tap(find.byTooltip('Document type'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Voter ID').last);
      await tester.pump(const Duration(milliseconds: 500));
      gate.complete();
      await tester.pump();
      await tester.pump();
      expect(find.text('Voter ID'), findsOneWidget);
      expect(text(tester, 'Name *'), 'Ravi');
      await tester.pumpWidget(const SizedBox());
      app.dispose();
    });

    testWidgets('a document removed while being read is ignored', (
      tester,
    ) async {
      final gate = Completer<void>();
      final reader = FakeReader(
        const DocumentDetails(kind: 'Aadhaar', name: 'Ravi'),
        gate: gate,
      );
      final app = await pumpForm(tester, reader: reader);
      await addPdf(tester);
      await tester.tap(find.byTooltip('Remove document'));
      await tester.pump();
      gate.complete();
      await tester.pump();
      await tester.pump();
      expect(text(tester, 'Name *'), isEmpty);
      expect(find.textContaining('Filled'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      app.dispose();
    });

    testWidgets('demo mode says its values are samples', (tester) async {
      final app = await pumpForm(tester, reader: const DemoDocumentReader());
      await addPdf(tester);
      await tester.pump(const Duration(seconds: 2));
      expect(find.textContaining('sample values'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      app.dispose();
    });

    testWidgets('without a reader nothing is attempted', (tester) async {
      final app = await pumpForm(tester);
      await addPdf(tester);
      expect(find.text('Reading name and address…'), findsNothing);
      expect(find.textContaining('Filled'), findsNothing);
      expect(documentKinds, contains('Utility bill'));
      await tester.pumpWidget(const SizedBox());
      app.dispose();
    });
  });
}
