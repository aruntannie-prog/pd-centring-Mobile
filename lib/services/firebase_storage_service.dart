import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FirebaseStorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Uploads byte data to Firebase Storage and returns the public download URL.
  /// Throws an exception if the upload fails so callers can surface the error.
  static Future<String> uploadImage({
    required String path,
    required Uint8List bytes,
  }) async {
    debugPrint('FirebaseStorageService: Uploading ${bytes.length} bytes to $path');
    debugPrint('FirebaseStorageService: Bucket = ${_storage.bucket}');

    final ref = _storage.ref().child(path);

    final metadata = SettableMetadata(
      contentType: 'image/jpeg',
    );

    final uploadTask = ref.putData(bytes, metadata);
    final snapshot = await uploadTask;

    final downloadUrl = await snapshot.ref.getDownloadURL();
    debugPrint('FirebaseStorageService: ✅ Upload complete: $downloadUrl');
    return downloadUrl;
  }

  /// Deletes a file from Firebase Storage given its HTTPS download URL.
  static Future<bool> deleteImage(String url) async {
    if (!url.contains('firebasestorage.googleapis.com')) {
      return false;
    }
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
      return true;
    } catch (e) {
      debugPrint('FirebaseStorageService: ❌ Delete failed: $e');
      return false;
    }
  }
}
