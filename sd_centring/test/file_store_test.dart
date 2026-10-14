// Customer photos and documents in Firebase Storage, against an in-memory
// Storage (firebase_storage_mocks): paths, file types, caching, size limit,
// deleting one file and a customer's whole folder.
import 'dart:typed_data';

import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sd_centring/data/file_store.dart';

void main() {
  late MockFirebaseStorage storage;
  late FirebaseFileStore store;
  final bytes = Uint8List.fromList(List.filled(2048, 7));

  setUp(() {
    storage = MockFirebaseStorage();
    store = FirebaseFileStore(storage);
  });

  test('an upload is stored at its path with type and long caching', () async {
    final progress = <double>[];
    final url = await store.upload(
      path: 'customers/c1/docs/d1.pdf',
      bytes: bytes,
      contentType: 'application/pdf',
      onProgress: progress.add,
    );
    expect(url, contains('customers/c1/docs/d1.pdf'));
    final meta = storage.storedSettableMetadataMap.values.single;
    expect(meta['contentType'], 'application/pdf');
    expect(meta['cacheControl'], 'private, max-age=31536000');
    expect(await storage.ref('customers/c1/docs/d1.pdf').getData(), bytes);
  });

  test('files over 10 MB are refused before uploading', () async {
    await expectLater(
      store.upload(
        path: 'customers/c1/docs/big.pdf',
        bytes: Uint8List(maxUploadBytes + 1),
        contentType: 'application/pdf',
      ),
      throwsA(
        isA<FileStoreException>().having(
          (e) => e.message,
          'message',
          contains('10 MB'),
        ),
      ),
    );
    expect(storage.storedSettableMetadataMap, isEmpty);
  });

  test('exactly 10 MB is accepted (same limit as storage.rules)', () async {
    final url = await store.upload(
      path: 'customers/c1/docs/edge.pdf',
      bytes: Uint8List(maxUploadBytes),
      contentType: 'application/pdf',
    );
    expect(url, isNotEmpty);
  });

  test('a file is deleted by its link', () async {
    final url = await store.upload(
      path: 'customers/c1/photo_1.jpg',
      bytes: bytes,
      contentType: 'image/jpeg',
    );
    await store.delete(url);
    expect(await storage.ref('customers/c1/photo_1.jpg').getData(), isNull);
  });

  test('deleting a missing file is harmless', () async {
    await store.delete(
      'https://firebasestorage.googleapis.com/v0/b/some-bucket/o/customers/x/gone.jpg',
    );
  });

  test("deleting a customer's folder removes all their files only", () async {
    for (final p in [
      'customers/c1/photo_1.jpg',
      'customers/c1/photo_1_thumb.jpg',
      'customers/c1/docs/a.pdf',
      'customers/c1/docs/b.jpg',
      'customers/c2/photo_9.jpg',
    ]) {
      await store.upload(path: p, bytes: bytes, contentType: 'image/jpeg');
    }
    await store.deleteFolder('customers/c1');
    for (final p in [
      'customers/c1/photo_1.jpg',
      'customers/c1/photo_1_thumb.jpg',
      'customers/c1/docs/a.pdf',
      'customers/c1/docs/b.jpg',
    ]) {
      expect(await storage.ref(p).getData(), isNull, reason: p);
    }
    expect(await storage.ref('customers/c2/photo_9.jpg').getData(), bytes);
  });

  group('demo / test store', () {
    test('keeps files in memory and hands them back for display', () async {
      final m = MemoryFileStore();
      final url = await m.upload(
        path: 'customers/c1/photo.png',
        bytes: bytes,
        contentType: 'image/png',
      );
      expect(url, startsWith('memory://'));
      expect(m.memoryBytes(url), bytes);
      await m.deleteFolder('customers/c1');
      expect(m.count, 0);
    });
  });
}
