import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

// Stub required so smart_cropper.dart compiles on native — never called at runtime
Future<List<int>?> cropFaceWeb(List<int> imageBytes, int targetSize) async =>
    null;

// Note: This file relies on _CropParams and _cropAndEncodeInIsolate being available
// in the scope where it's imported (smart_cropper.dart).
// However, since it's a separate file, we need a way to share those or re-define them.
// To avoid duplication, we'll import them from smart_cropper.dart, 
// BUT that might cause a circular dependency.
// Alternative: Move those common pieces to a third 'smart_cropper_utils.dart' file.

Future<List<int>> nativeCropToFace(List<int> imageBytes, int targetSize) async {
  final bytes = Uint8List.fromList(imageBytes);
  int cropX = 0, cropY = 0, sideLength = 0;

  try {
    final dimImage = img.decodeImage(bytes);
    if (dimImage != null) {
      sideLength = dimImage.width < dimImage.height ? dimImage.width : dimImage.height;
      cropX = (dimImage.width - sideLength) ~/ 2;
      cropY = (dimImage.height - sideLength) ~/ 2;
    }
  } catch (_) {}

  try {
    final tempFile = File(
        '${Directory.systemTemp.path}/temp_face_crop_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await tempFile.writeAsBytes(bytes);

    final faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.fast,
      ),
    );

    final faces = await faceDetector.processImage(InputImage.fromFilePath(tempFile.path));
    await faceDetector.close();
    if (await tempFile.exists()) await tempFile.delete();

    if (faces.isNotEmpty) {
      final rect = faces.first.boundingBox;
      final faceCenterX = rect.left + rect.width / 2;
      final faceCenterY = rect.top + rect.height / 2;
      sideLength = ((rect.width > rect.height ? rect.width : rect.height) * 1.5).toInt();

      final dimChk = img.decodeImage(bytes);
      if (dimChk != null) {
        if (sideLength > dimChk.width) sideLength = dimChk.width;
        if (sideLength > dimChk.height) sideLength = dimChk.height;
        cropX = (faceCenterX - sideLength / 2).toInt().clamp(0, dimChk.width - sideLength);
        cropY = (faceCenterY - sideLength / 2).toInt().clamp(0, dimChk.height - sideLength);
      }
    }
  } catch (e) {
    debugPrint('NativeCropper Error: $e');
  }

  if (sideLength == 0) return imageBytes;

  // We'll call the functions that are expected to be available in the importing file
  // or we redefine them here for robustness if isolate boundary allows.
  return compute(
    _cropAndEncodeInIsolateNative,
    _CropParamsNative(bytes, cropX, cropY, sideLength, targetSize),
  );
}

class _CropParamsNative {
  final Uint8List imageBytes;
  final int cropX, cropY, sideLength, targetSize;
  const _CropParamsNative(this.imageBytes, this.cropX, this.cropY, this.sideLength,
      this.targetSize);
}

List<int> _cropAndEncodeInIsolateNative(_CropParamsNative p) {
  final original = img.decodeImage(p.imageBytes);
  if (original == null) return p.imageBytes;

  final cropped = img.copyCrop(
    original,
    x: p.cropX,
    y: p.cropY,
    width: p.sideLength,
    height: p.sideLength,
  );
  final resized = img.copyResize(cropped, width: p.targetSize, height: p.targetSize);
  return img.encodeJpg(resized, quality: 85);
}
