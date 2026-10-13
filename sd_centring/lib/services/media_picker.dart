import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'image_shrink.dart';

/// A file chosen by the user, already in memory.
class PickedMedia {
  const PickedMedia({
    required this.name,
    required this.bytes,
    required this.contentType,
  });

  final String name;
  final Uint8List bytes;
  final String contentType;
}

String contentTypeFor(String fileName) {
  final ext = fileName.split('.').last.toLowerCase();
  return switch (ext) {
    'pdf' => 'application/pdf',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'heic' => 'image/heic',
    _ => 'image/jpeg',
  };
}

/// Camera, gallery and file picking. Replaceable in tests.
///
/// Every image comes back already made smaller for upload (see
/// [shrinkImage]); PDFs are returned exactly as picked, because shrinking
/// a PDF would mean re-rendering it and losing sharpness.
class MediaPicker {
  const MediaPicker();

  /// The picker the app uses; tests swap in a fake.
  static MediaPicker instance = const MediaPicker();

  /// Profile photo: 1024 px is plenty for a face (typically 100–250 KB).
  Future<PickedMedia?> photo({required bool camera}) =>
      _image(camera: camera, maxSide: 1024, quality: 82, front: true);

  /// Photo of an ID card or bill: 2000 px keeps small print readable
  /// (typically 300–700 KB instead of 3–8 MB straight from the camera).
  Future<PickedMedia?> documentPhoto({required bool camera}) => _image(
    camera: camera,
    maxSide: docMaxSide.toDouble(),
    quality: 85,
    front: false,
  );

  static const docMaxSide = 2000;

  /// A PDF or image file from the phone or computer.
  Future<PickedMedia?> documentFile() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
    );
    if (files.isEmpty) return null;
    final f = files.first;
    final type = contentTypeFor(f.name);
    final bytes = await f.readAsBytes();
    if (!type.startsWith('image/')) {
      return PickedMedia(name: f.name, bytes: bytes, contentType: type);
    }
    // Images chosen as files skip the camera's own resizing, so shrink here.
    final small = await shrinkImage(
      bytes,
      contentType: type,
      maxSide: docMaxSide,
      skipBelowBytes: 700 * 1024,
    );
    return PickedMedia(
      name: _renamed(f.name, small.contentType),
      bytes: small.bytes,
      contentType: small.contentType,
    );
  }

  Future<PickedMedia?> _image({
    required bool camera,
    required double maxSide,
    required int quality,
    required bool front,
  }) async {
    final x = await ImagePicker().pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: maxSide,
      maxHeight: maxSide,
      imageQuality: quality,
      preferredCameraDevice: front ? CameraDevice.front : CameraDevice.rear,
    );
    if (x == null) return null;
    final name = x.name.isEmpty ? 'photo.jpg' : x.name;
    // The picker already resized it on most phones; this also covers
    // browsers and devices where it could not, and fixes rotation.
    final small = await shrinkImage(
      await x.readAsBytes(),
      contentType: (x.mimeType?.isNotEmpty ?? false)
          ? x.mimeType!
          : contentTypeFor(name),
      maxSide: maxSide.round(),
      quality: quality,
      skipBelowBytes: maxSide > 1500 ? 700 * 1024 : 300 * 1024,
    );
    return PickedMedia(
      name: _renamed(name, small.contentType),
      bytes: small.bytes,
      contentType: small.contentType,
    );
  }

  /// "IMG_1234.HEIC" → "IMG_1234.jpg" when the image was re-encoded.
  static String _renamed(String name, String contentType) {
    final want = contentType == 'image/png' ? 'png' : 'jpg';
    if (contentTypeFor(name) == contentType) return name;
    final dot = name.lastIndexOf('.');
    return '${dot > 0 ? name.substring(0, dot) : name}.$want';
  }
}
