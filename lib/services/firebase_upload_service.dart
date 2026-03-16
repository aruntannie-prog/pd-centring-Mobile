import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class FirebaseUploadService {
  static final _storage = FirebaseStorage.instance;

  /// Uploads [bytes] to [storagePath] and returns the public download URL.
  /// Times out after 30 s — callers should catch and fall back to base64.
  static Future<String> uploadBytes(
    Uint8List bytes,
    String storagePath, {
    String contentType = 'application/octet-stream',
  }) async {
    final ref = _storage.ref().child(storagePath);
    final metadata = SettableMetadata(contentType: contentType);
    await ref
        .putData(bytes, metadata)
        .timeout(const Duration(seconds: 30));
    return await ref
        .getDownloadURL()
        .timeout(const Duration(seconds: 15));
  }

  /// Unique storage path for a customer profile photo.
  static String profilePath() =>
      'customers/profile/${DateTime.now().millisecondsSinceEpoch}.jpg';

  /// Unique storage path for an address proof document.
  static String proofPath(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    return 'customers/proofs/${DateTime.now().millisecondsSinceEpoch}.$ext';
  }

  static String mimeForFile(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    if (ext == 'pdf') return 'application/pdf';
    if (ext == 'png') return 'image/png';
    return 'image/jpeg';
  }
}
