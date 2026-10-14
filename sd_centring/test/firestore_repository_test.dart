// The Firestore storage layer, against an in-memory Firestore
// (fake_cloud_firestore): what the app writes is what it reads back.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_exceptions/mock_exceptions.dart';
import 'package:sd_centring/data/firestore_repository.dart';
import 'package:sd_centring/data/repository.dart';
import 'package:sd_centring/models/customer.dart';
import 'package:sd_centring/models/rental.dart';

Customer customer() => Customer(
  id: 'c1',
  name: 'Murugan Builders',
  phone: '9840012345',
  altPhone: '9000011111',
  address: 'Tambaram',
  notes: 'Pays monthly',
  photoUrl: 'https://x/p.jpg',
  photoThumbUrl: 'https://x/p_thumb.jpg',
  documents: [
    CustomerDoc(
      id: 'd1',
      kind: 'Aadhaar',
      fileName: 'a.jpg',
      url: 'https://x/a.jpg',
      contentType: 'image/jpeg',
      sizeBytes: 1234,
      uploadedAt: DateTime(2026, 10, 1),
    ),
  ],
  createdAt: DateTime(2026, 9, 1),
);

Rental rental() => Rental(
  id: 'r1',
  dcNumber: 'SD-1001',
  customerId: 'c1',
  customerName: 'Murugan Builders',
  site: 'Selaiyur',
  issuedOn: DateTime(2026, 9, 1),
  expiresOn: DateTime(2026, 10, 1),
  items: const [
    RentalItem(id: 'i1', name: 'Props', qty: 40),
    RentalItem(id: 'i2', name: 'Span', qty: 12.5, unit: 'ft'),
  ],
  returns: [
    ReturnEntry(id: 'x1', itemId: 'i1', qty: 15, date: DateTime(2026, 9, 20)),
  ],
  createdAt: DateTime(2026, 9, 1),
  updatedAt: DateTime(2026, 9, 1),
);

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreRepository repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = FirestoreRepository(db);
  });
  tearDown(() => repo.dispose());

  test('starts as "connecting", not "offline"', () {
    expect(repo.sync.value, SyncState.connecting);
    expect(repo.isDemo, isFalse);
  });

  test('a saved customer is read back with every field', () async {
    await repo.saveCustomer(customer());
    final list = await repo.watchCustomers().first;
    final c = list.single;
    expect(c.name, 'Murugan Builders');
    expect(c.altPhone, '9000011111');
    expect(c.notes, 'Pays monthly');
    expect(c.photoThumbUrl, 'https://x/p_thumb.jpg');
    expect(c.documents.single.kind, 'Aadhaar');
    expect(c.documents.single.sizeBytes, 1234);
    expect(c.createdAt, DateTime(2026, 9, 1));
    // Stored as plain fields Firestore rules can check.
    final raw = (await db.collection('customers').doc('c1').get()).data()!;
    expect(raw['createdAt'], isA<int>());
    expect(raw.containsKey('referredBy'), isFalse);
  });

  test('a saved delivery is read back with items, units and returns', () async {
    await repo.saveRental(rental());
    final r = (await repo.watchRentals().first).single;
    expect(r.dcNumber, 'SD-1001');
    expect(r.items[1].unit, 'ft');
    expect(r.items[1].qty, 12.5);
    expect(r.returnedQty('i1'), 15);
    expect(r.outstandingQty(r.items[0]), 25);
    final raw = (await db.collection('rentals').doc('r1').get()).data()!;
    expect(raw['issuedOn'], '2026-09-01'); // calendar day, no time zone
    expect(raw['expiresOn'], '2026-10-01');
  });

  test('a malformed delivery is skipped, the rest still load', () async {
    await repo.saveRental(rental());
    await db.collection('rentals').doc('bad').set({'dcNumber': 42});
    final list = await repo.watchRentals().first;
    expect(list.map((r) => r.id), ['r1']);
  });

  test('a customer with odd data still loads', () async {
    await db.collection('customers').doc('odd').set({
      'name': 'Ravi',
      'phone': 9123456780, // number instead of text
      'documents': 'not a list',
    });
    final c = (await repo.watchCustomers().first).single;
    expect(c.name, 'Ravi');
    expect(c.documents, isEmpty);
  });

  test('deletes remove the records', () async {
    await repo.saveCustomer(customer());
    await repo.saveRental(rental());
    await repo.deleteCustomer('c1');
    await repo.deleteRental('r1');
    expect(await repo.watchCustomers().first, isEmpty);
    expect(await repo.watchRentals().first, isEmpty);
  });

  test('live updates arrive on the stream', () async {
    final seen = <int>[];
    final sub = repo.watchCustomers().listen((l) => seen.add(l.length));
    await pumpEventQueue();
    await repo.saveCustomer(customer());
    await pumpEventQueue();
    await sub.cancel();
    expect(seen.first, 0);
    expect(seen.last, 1);
  });

  test('data confirmed by the server shows as synced', () async {
    final subs = [
      repo.watchCustomers().listen((_) {}),
      repo.watchRentals().listen((_) {}),
    ];
    await pumpEventQueue();
    expect(repo.sync.value, SyncState.synced);
    for (final s in subs) {
      await s.cancel();
    }
  });

  test('a refused write is reported, never silent', () async {
    final doc = db.collection('customers').doc('c1');
    whenCalling(Invocation.method(#set, null))
        .on(doc)
        .thenThrow(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          ),
        );
    final errors = <String>[];
    final sub = repo.writeErrors.listen(errors.add);
    // Returns at once: a write never makes the app wait for the server.
    await repo.saveCustomer(customer()).timeout(const Duration(seconds: 1));
    await pumpEventQueue();
    await sub.cancel();
    expect(errors.single, contains('staff list'));
  });

  test(
    'a failed write for other reasons says to check the connection',
    () async {
      final doc = db.collection('rentals').doc('r1');
      whenCalling(Invocation.method(#set, null))
          .on(doc)
          .thenThrow(
            FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
          );
      final errors = <String>[];
      final sub = repo.writeErrors.listen(errors.add);
      await repo.saveRental(rental());
      await pumpEventQueue();
      await sub.cancel();
      expect(errors.single, contains('check your connection'));
    },
  );
}
