import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FirebaseStorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Uploads byte data to Firebase Storage and returns the public download URL.
  static Future<String?> uploadImage({
    required String path,
    required Uint8List bytes,
  }) async {
    try {
      debugPrint('FirebaseStorageService: Uploading to $path...');
      final ref = _storage.ref().child(path);
      
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'uploaded_at': DateTime.now().toIso8601String()},
      );

      final uploadTask = ref.putData(bytes, metadata);
      final snapshot = await uploadTask;
      
      final downloadUrl = await snapshot.ref.getDownloadURL();
      debugPrint('FirebaseStorageService: ✅ Upload complete: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('FirebaseStorageService: ❌ Upload failed: $e');
      return null;
    }
  }

  /// Deletes a file from Firebase Storage given its HTTPS download URL.
  static Future<bool> deleteImage(String url) async {
    if (!url.contains('firebasestorage.googleapis.com')) {
      debugPrint('FirebaseStorageService: URL is not a Firebase Storage URL: $url');
      return false;
    }
    
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
      debugPrint('FirebaseStorageService: ✅ Deleted from storage: $url');
      return true;
    } catch (e) {
      debugPrint('FirebaseStorageService: ❌ Delete failed: $e');
      return false;
    }
  }
}
