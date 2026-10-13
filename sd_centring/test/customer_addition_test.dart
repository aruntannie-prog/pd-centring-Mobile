// Adding customers is SD's main job, so every path through it is covered:
// validation, duplicates, drafts, sync status, search, sort and editing.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sd_centring/data/file_store.dart';
import 'package:sd_centring/data/memory_repository.dart';
import 'package:sd_centring/models/customer.dart';
import 'package:sd_centring/services/media_picker.dart';
import 'package:sd_centring/services/reminder_scheduler.dart';
import 'package:sd_centring/state/app_state.dart';
import 'package:sd_centring/state/drafts.dart';
import 'package:sd_centring/state/settings.dart';
import 'package:sd_centring/ui/screens/customer_form_screen.dart';

import 'flows_test.dart' show Harness, appTest;
import 'support.dart';

Customer customer(
  String id,
  String name,
  String phone, {
  String altPhone = '',
  String address = '',
  DateTime? createdAt,
  List<CustomerDoc> documents = const [],
}) => Customer(
  id: id,
  name: name,
  phone: phone,
  altPhone: altPhone,
  address: address,
  documents: documents,
  createdAt: createdAt ?? DateTime(2026, 1, 1),
);

Finder field(String label) => find.widgetWithText(TextFormField, label);

Future<void> fill(WidgetTester tester, String name, String phone) async {
  await tester.enterText(field('Name *'), name);
  await tester.enterText(field('Phone *'), phone);
}

Future<void> save(WidgetTester tester) async {
  await tester.tap(find.text('SAVE'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  group('rules shared with the database', () {
    test('phone numbers', () {
      expect(phoneProblem('', required: true), 'Enter a phone number');
      expect(phoneProblem('', required: false), isNull);
      expect(phoneProblem('98400', required: true), contains('Too short'));
      expect(phoneProblem('9840012345', required: true), isNull);
      expect(phoneProblem('+91 98400 12345', required: true), isNull);
      expect(phoneProblem('044-2345 6789', required: true), isNull);
      expect(phoneProblem('98400 1234x', required: true), 'Use digits only');
      expect(phoneProblem('98+40012345', required: true), contains('"+"'));
      expect(
        phoneProblem('+91 98400 12345 678', required: true),
        contains('Too long'),
      );
    });

    test('a saved phone always fits the database rule (10–16 chars)', () {
      for (final typed in [
        '9840012345',
        '+91 98400 12345',
        '+91 (984) 001-2345',
        '044 2345 6789',
      ]) {
        expect(phoneProblem(typed, required: true), isNull, reason: typed);
        final stored = normalizePhone(typed);
        expect(stored.length, inInclusiveRange(10, 16), reason: typed);
      }
    });

    test('names are tidied', () {
      expect(tidyText('  Ravi   Kumar '), 'Ravi Kumar');
    });

    test('search matches name, address, phone and alternate phone', () {
      final c = customer(
        'c',
        'Murugan Builders',
        '9840012345',
        altPhone: '+91 90000 11111',
        address: 'Tambaram',
      );
      expect(c.matches(''), isTrue);
      expect(c.matches('murugan'), isTrue);
      expect(c.matches('TAMBARAM'), isTrue);
      expect(c.matches('98400'), isTrue);
      expect(c.matches('+91 98400 12345'), isTrue);
      expect(c.matches('11111'), isTrue);
      expect(c.matches('12'), isFalse); // too few digits to mean a phone
      expect(c.matches('Lakshmi'), isFalse);
    });

    test('duplicates are found through main and alternate numbers', () {
      final app = AppState(
        repo: MemoryRepository(
          customers: [
            customer('a', 'A', '9840012345'),
            customer('b', 'B', '9000000001', altPhone: '9000011111'),
          ],
        ),
        settings: ReminderSettings.inMemory(),
        scheduler: NoopReminderScheduler(),
      );
      addTearDown(app.dispose);
      return Future(() {
        expect(app.customersWithPhone(['+91 98400 12345']).single.id, 'a');
        expect(app.customersWithPhone(['90000 11111']).single.id, 'b');
        expect(app.customersWithPhone(['9840012345'], exceptId: 'a'), isEmpty);
        expect(app.customersWithPhone(['', '123']), isEmpty);
      });
    });

    test('drafts survive a reload of the store', () {
      final d = DraftStore.inMemory();
      expect(d.read('x'), isNull);
      d.write('x', {'name': 'Ravi'});
      expect(d.read('x'), {'name': 'Ravi'});
      d.clear('x');
      expect(d.read('x'), isNull);
    });
  });

  group('new customer form', () {
    testWidgets('saves a tidy record with only name and phone', (tester) async {
      final app = await pumpForm(tester);
      await fill(tester, '  Ravi   Kumar ', '+91 98400 12345');
      await save(tester);
      final c = app.customers.single;
      expect(c.name, 'Ravi Kumar');
      expect(c.phone, '+919840012345');
      expect(c.photoUrl, isEmpty);
      expect(c.documents, isEmpty);
      expect(c.createdAt.year, greaterThan(2000));
      await tester.pumpWidget(const SizedBox());
      app.dispose();
    });

    testWidgets('empty form shows what is missing and saves nothing', (
      tester,
    ) async {
      final app = await pumpForm(tester);
      await save(tester);
      expect(find.text('Enter the customer name'), findsOneWidget);
      expect(find.text('Enter a phone number'), findsOneWidget);
      expect(find.text('Please fix the highlighted fields.'), findsOneWidget);
      expect(app.customers, isEmpty);
      await tester.pumpWidget(const SizedBox());
      app.dispose();
    });

    testWidgets('letters cannot be typed into phone fields', (tester) async {
      final app = await pumpForm(tester);
      await tester.enterText(field('Phone *'), '98a40b012345');
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText).at(1))
            .controller
            .text,
        '9840012345',
      );
      await tester.pumpWidget(const SizedBox());
      app.dispose();
    });

    testWidgets('alternate number cannot repeat the main one', (tester) async {
      final app = await pumpForm(tester);
      await fill(tester, 'Ravi', '9840012345');
      await tester.enterText(field('Alternate phone'), '+91 98400 12345');
      await save(tester);
      expect(find.text('Same as the main number'), findsOneWidget);
      expect(app.customers, isEmpty);
      await tester.pumpWidget(const SizedBox());
      app.dispose();
    });

    testWidgets('a number already used as someone\'s alternate is caught', (
      tester,
    ) async {
      final app = await pumpForm(
        tester,
        others: [
          customer('b', 'Lakshmi', '9000000001', altPhone: '9840012345'),
        ],
      );
      await fill(tester, 'Ravi', '98400 12345');
      await save(tester);
      expect(find.text('Number already saved'), findsOneWidget);
      expect(find.textContaining('Lakshmi'), findsOneWidget);
      await tester.tap(find.text('Go back'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(app.customers.length, 1); // only Lakshmi
      expect(find.text('New customer'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      app.dispose();
    });

    testWidgets('typed details come back after the app was closed', (
      tester,
    ) async {
      final app = await pumpForm(tester);
      await fill(tester, 'Selvam', '90000');
      await tester.enterText(field('Address'), 'Selaiyur');
      await tester.tap(find.text('Add photo'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Take photo'),
        ),
      );
      await tester.pumpAndSettle();

      // The app is killed: the screen goes away without saving.
      await tester.pumpWidget(const SizedBox());

      await pumpForm(tester, reuse: app);
      expect(find.text('Restored what you typed earlier'), findsOneWidget);
      expect(find.text('Add the photo or document again.'), findsOneWidget);
      expect(find.text('Selvam'), findsOneWidget);
      expect(find.text('Selaiyur'), findsOneWidget);

      await tester.enterText(field('Phone *'), '9000011111');
      await save(tester);
      expect(app.customers.single.address, 'Selaiyur');
      expect(app.drafts.read(newCustomerDraftKey(null)), isNull);
      await tester.pumpWidget(const SizedBox());
      app.dispose();
    });

    testWidgets('start over clears a restored draft', (tester) async {
      final app = await pumpForm(tester);
      await fill(tester, 'Selvam', '90000');
      await tester.pumpWidget(const SizedBox());
      await pumpForm(tester, reuse: app);
      await tester.tap(find.text('Start over'));
      await tester.pump();
      expect(find.text('Restored what you typed earlier'), findsNothing);
      expect(find.text('Selvam'), findsNothing);
      expect(app.drafts.read(newCustomerDraftKey(null)), isNull);
      await tester.pumpWidget(const SizedBox());
      app.dispose();
    });

    testWidgets('editing never touches the new customer draft', (tester) async {
      final existing = customer('c', 'Ravi', '9840012345');
      final app = await pumpForm(tester, existing: existing);
      await tester.enterText(field('Name *'), 'Ravi Kumar');
      expect(app.drafts.read(newCustomerDraftKey(null)), isNull);
      await save(tester);
      expect(app.customerById('c')!.name, 'Ravi Kumar');
      await tester.pumpWidget(const SizedBox());
      app.dispose();
    });

    testWidgets('replacing a photo deletes the old file after saving', (
      tester,
    ) async {
      final files = MemoryFileStore();
      final old = await files.upload(
        path: 'customers/c/photo_1.png',
        bytes: png,
        contentType: 'image/png',
      );
      final app = await pumpForm(
        tester,
        files: files,
        existing: customer('c', 'Ravi', '9840012345').copyWith(photoUrl: old),
      );
      expect(find.text('Change'), findsOneWidget);
      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose from gallery'));
      await tester.pumpAndSettle();
      await save(tester);
      final c = app.customerById('c')!;
      expect(c.photoUrl, isNot(old));
      expect(files.memoryBytes(old), isNull);
      expect(c.photoThumbUrl, isNotEmpty);
      expect(files.count, 2); // new photo and its thumbnail
      await tester.pumpWidget(const SizedBox());
      app.dispose();
    });

    testWidgets('save waits for an upload that is still running', (
      tester,
    ) async {
      final store = SlowStore();
      final app = await pumpForm(tester, files: store);
      await tester.tap(find.text('Upload file'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(store.started, 1); // started as soon as it was picked
      expect(find.textContaining('uploading 40%'), findsOneWidget);
      await fill(tester, 'Ravi', '9840012345');
      await save(tester);
      expect(find.text('Uploading… 40%'), findsOneWidget);
      expect(app.customers, isEmpty);
      store.release();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(app.customers.single.documents, hasLength(1));
      await tester.pumpWidget(const SizedBox());
      app.dispose();
    });

    testWidgets('a document removed while uploading leaves no file behind', (
      tester,
    ) async {
      final store = SlowStore();
      final app = await pumpForm(tester, files: store);
      await tester.tap(find.text('Upload file'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byTooltip('Remove document'));
      await tester.pump();
      store.release();
      await tester.pump();
      await tester.pump();
      expect(store.count, 0);
      await tester.pumpWidget(const SizedBox());
      app.dispose();
    });

    testWidgets('editing changes only what was changed on this screen', (
      tester,
    ) async {
      final files = MemoryFileStore();
      Future<String> put(String path) =>
          files.upload(path: path, bytes: png, contentType: 'image/png');
      final p1 = await put('customers/c/photo_1.png');
      final d1 = CustomerDoc(
        id: 'd1',
        kind: 'Aadhaar',
        fileName: 'a.png',
        url: await put('customers/c/docs/d1.png'),
        contentType: 'image/png',
        sizeBytes: 1,
        uploadedAt: DateTime(2026),
      );
      final original = customer(
        'c',
        'Ravi',
        '9840012345',
        address: 'Tambaram',
        documents: [d1],
      ).copyWith(photoUrl: p1);
      final app = await pumpForm(tester, files: files, existing: original);

      // Meanwhile another phone changes the photo, the name and adds a
      // document.
      final p2 = await put('customers/c/photo_2.png');
      final d2 = CustomerDoc(
        id: 'd2',
        kind: 'PAN',
        fileName: 'p.png',
        url: await put('customers/c/docs/d2.png'),
        contentType: 'image/png',
        sizeBytes: 1,
        uploadedAt: DateTime(2026),
      );
      await app.saveCustomer(
        original.copyWith(
          name: 'Ravi Kumar',
          photoUrl: p2,
          documents: [d1, d2],
        ),
      );
      await tester.pump();

      // This phone only changes the address.
      await tester.enterText(field('Address'), 'Selaiyur');
      await save(tester);

      final c = app.customerById('c')!;
      expect(c.address, 'Selaiyur');
      expect(c.name, 'Ravi Kumar');
      expect(c.photoUrl, p2);
      expect(c.documents.map((d) => d.id), ['d1', 'd2']);
      expect(files.memoryBytes(p2), isNotNull);
      await tester.pumpWidget(const SizedBox());
      app.dispose();
    });

    testWidgets('a file over 10 MB is refused before upload', (tester) async {
      final app = await pumpForm(tester);
      MediaPicker.instance = const BigPicker();
      await tester.tap(find.text('Upload file'));
      await tester.pumpAndSettle();
      expect(find.textContaining('larger than 10 MB'), findsOneWidget);
      expect(find.textContaining('huge.pdf'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      app.dispose();
    });
  });

  group('customers list', () {
    Harness harness({Set<String> pending = const {}}) {
      final repo = CloudLikeRepository(
        customers: [
          customer('a', 'Arun', '9000000001', createdAt: DateTime(2026, 1, 5)),
          customer(
            'z',
            'Zahir',
            '9000000002',
            altPhone: '9444455555',
            createdAt: DateTime(2026, 9, 1),
            documents: [
              CustomerDoc(
                id: 'd',
                kind: 'Aadhaar',
                fileName: 'a.png',
                url: 'memory://x',
                contentType: 'image/png',
                sizeBytes: 10,
                uploadedAt: DateTime(2026),
              ),
            ],
          ),
          customer('m', 'Mani', '9000000003', createdAt: DateTime(2026, 5, 1)),
        ],
      );
      repo.pendingCustomers.value = pending;
      return Harness(repo);
    }

    Future<void> openCustomers(WidgetTester tester) async {
      await tester.tap(find.text('Customers'));
      await tester.pumpAndSettle();
    }

    List<String> order(WidgetTester tester) {
      final names = ['Arun', 'Mani', 'Zahir'];
      final ys = {for (final n in names) n: tester.getTopLeft(find.text(n)).dy};
      return names.toList()..sort((a, b) => ys[a]!.compareTo(ys[b]!));
    }

    appTest('A–Z by default, newest first on request', harness: harness, (
      tester,
      h,
    ) async {
      await openCustomers(tester);
      expect(order(tester), ['Arun', 'Mani', 'Zahir']);
      await tester.tap(find.text('Newest first'));
      await tester.pumpAndSettle();
      expect(order(tester), ['Zahir', 'Mani', 'Arun']);
    });

    appTest(
      'shows ID proof and cloud status on every row',
      harness: () => harness(pending: {'m'}),
      (tester, h) async {
        await openCustomers(tester);
        expect(find.textContaining('2 without ID proof'), findsOneWidget);
        expect(find.text('No ID proof'), findsNWidgets(2));
        expect(find.text('1 ID / proof'), findsOneWidget);
        expect(find.text('Not in cloud yet'), findsOneWidget);
        expect(find.text('In cloud'), findsNWidgets(2));

        // The customer page explains it too.
        await tester.tap(find.text('Mani'));
        await tester.pumpAndSettle();
        expect(find.text('Not in the cloud yet'), findsOneWidget);
        expect(find.textContaining('Added 1 May 2026'), findsOneWidget);

        // Once the server confirms, the warning goes away by itself.
        (h.repo as CloudLikeRepository).pendingCustomers.value = {};
        await tester.pumpAndSettle();
        expect(find.text('Not in the cloud yet'), findsNothing);
      },
    );

    appTest('search finds an alternate number', harness: harness, (
      tester,
      h,
    ) async {
      await openCustomers(tester);
      await tester.enterText(find.byType(TextField).first, '94444');
      await tester.pumpAndSettle();
      expect(find.text('Zahir'), findsOneWidget);
      expect(find.text('Arun'), findsNothing);
    });

    appTest(
      'adding from the list confirms and links to the customer',
      harness: harness,
      (tester, h) async {
        await openCustomers(tester);
        await tester.tap(find.text('Add customer'));
        await tester.pumpAndSettle();
        await fill(tester, 'Bala', '9876543210');
        await tester.tap(find.text('SAVE'));
        await tester.pumpAndSettle();
        expect(find.text('Bala added'), findsOneWidget);
        await tester.tap(find.text('VIEW'));
        await tester.pumpAndSettle();
        expect(find.text('Customer'), findsOneWidget);
        expect(find.text('9876543210'), findsOneWidget);
      },
    );

    appTest('editing confirms with "Changes saved"', harness: harness, (
      tester,
      h,
    ) async {
      await openCustomers(tester);
      await tester.tap(find.text('Arun'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Edit'));
      await tester.pumpAndSettle();
      await tester.enterText(field('Name *'), 'Arun Kumar');
      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();
      expect(find.text('Changes saved'), findsOneWidget);
      expect(find.text('Arun Kumar'), findsOneWidget);
    });
  });
}

/// Behaves like the cloud database: not demo, so "In cloud" marks show.
class CloudLikeRepository extends MemoryRepository {
  CloudLikeRepository({super.customers});

  @override
  bool get isDemo => false;
}
