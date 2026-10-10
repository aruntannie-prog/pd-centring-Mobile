import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

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
class MediaPicker {
  const MediaPicker();

  /// The picker the app uses; tests swap in a fake.
  static MediaPicker instance = const MediaPicker();

  /// Profile photo: resized on the device so uploads stay small and fast.
  Future<PickedMedia?> photo({required bool camera}) =>
      _image(camera: camera, maxSide: 1024, quality: 82, front: true);

  /// Photo of an ID card or bill: larger so the text stays readable.
  Future<PickedMedia?> documentPhoto({required bool camera}) =>
      _image(camera: camera, maxSide: 2000, quality: 85, front: false);

  /// A PDF or image file from the phone or computer.
  Future<PickedMedia?> documentFile() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
    );
    if (files.isEmpty) return null;
    final f = files.first;
    return PickedMedia(
      name: f.name,
      bytes: await f.readAsBytes(),
      contentType: contentTypeFor(f.name),
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
    return PickedMedia(
      name: name,
      bytes: await x.readAsBytes(),
      contentType: x.mimeType ?? contentTypeFor(name),
    );
  }
}
