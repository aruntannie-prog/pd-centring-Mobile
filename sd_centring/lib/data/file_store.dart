import 'dart:async';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

/// Where customer photos and documents are kept.
///
/// Files go to Firebase Storage and only their URL is saved on the customer
/// record. (The PD app stored photos as base64 text inside the database
/// record, which runs into Firestore's 1 MB document limit.)
abstract class FileStore {
  /// Uploads [bytes] and returns a URL that [StoredImage] / viewers can open.
  /// Throws [FileStoreException] with a user-facing message on failure.
  Future<String> upload({
    required String path,
    required Uint8List bytes,
    required String contentType,
    void Function(double progress)? onProgress,
  });

  /// Best effort: a failed delete only leaves an orphaned file behind.
  Future<void> delete(String url);

  /// Bytes for `memory://` URLs (demo mode); null for real URLs.
  Uint8List? memoryBytes(String url) => null;
}

class FileStoreException implements Exception {
  FileStoreException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Largest file accepted (photos are resized before this check).
const int maxUploadBytes = 10 * 1024 * 1024;

/// Firebase Storage. Uploads need a connection; they time out instead of
/// spinning forever (a problem the PD app had on the web).
class FirebaseFileStore implements FileStore {
  FirebaseFileStore(this._storage);

  final FirebaseStorage _storage;

  @override
  Future<String> upload({
    required String path,
    required Uint8List bytes,
    required String contentType,
    void Function(double progress)? onProgress,
  }) async {
    if (bytes.length > maxUploadBytes) {
      throw FileStoreException('File is larger than 10 MB.');
    }
    final ref = _storage.ref(path);
    final task = ref.putData(bytes, SettableMetadata(contentType: contentType));
    final sub = task.snapshotEvents.listen((s) {
      if (s.totalBytes > 0) onProgress?.call(s.bytesTransferred / s.totalBytes);
    }, onError: (_) {});
    try {
      await task.timeout(const Duration(seconds: 90));
      return await ref.getDownloadURL().timeout(const Duration(seconds: 20));
    } on TimeoutException {
      await task.cancel();
      throw FileStoreException(
        'Upload timed out. Check the internet connection and try again.',
      );
    } on FirebaseException catch (e) {
      debugPrint('FirebaseFileStore: ${e.code} ${e.message}');
      throw FileStoreException(
        e.code == 'unauthorized'
            ? 'Not allowed to upload. Ask the owner to add your account to the staff list.'
            : 'Upload failed. Please try again.',
      );
    } finally {
      await sub.cancel();
    }
  }

  @override
  Future<void> delete(String url) async {
    try {
      await _storage.refFromURL(url).delete();
    } catch (e) {
      debugPrint('FirebaseFileStore: could not delete $url: $e');
    }
  }

  @override
  Uint8List? memoryBytes(String url) => null;
}

/// Keeps files in memory for demo mode and tests. Nothing is persisted.
class MemoryFileStore implements FileStore {
  final _files = <String, Uint8List>{};

  int get count => _files.length;

  @override
  Future<String> upload({
    required String path,
    required Uint8List bytes,
    required String contentType,
    void Function(double progress)? onProgress,
  }) async {
    if (bytes.length > maxUploadBytes) {
      throw FileStoreException('File is larger than 10 MB.');
    }
    onProgress?.call(1);
    final url = 'memory://${const Uuid().v4()}/$path';
    _files[url] = bytes;
    return url;
  }

  @override
  Future<void> delete(String url) async => _files.remove(url);

  @override
  Uint8List? memoryBytes(String url) => _files[url];
}
