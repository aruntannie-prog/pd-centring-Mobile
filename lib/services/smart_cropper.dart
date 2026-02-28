import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'smart_cropper_stub.dart'
    if (dart.library.html) 'smart_cropper_web.dart';

// ─── Data classes passed to/from compute() isolate ───────────────────────────

class _CropParams {
  final Uint8List imageBytes;
  final int cropX, cropY, sideLength, targetSize;
  const _CropParams(this.imageBytes, this.cropX, this.cropY, this.sideLength,
      this.targetSize);
}

/// Top-level function — runs inside a background isolate via compute().
/// Does decode → crop → resize → encode entirely off the UI thread.
List<int> _cropAndEncodeInIsolate(_CropParams p) {
  final original = img.decodeImage(p.imageBytes);
  if (original == null) return p.imageBytes;

  final cropped = img.copyCrop(
    original,
    x: p.cropX,
    y: p.cropY,
    width: p.sideLength,
    height: p.sideLength,
  );
  final resized =
      img.copyResize(cropped, width: p.targetSize, height: p.targetSize);
  return img.encodeJpg(resized, quality: 85);
}

// ─── SmartCropper ─────────────────────────────────────────────────────────────

class SmartCropper {
  /// Crops the given image bytes to a square around the detected face.
  /// Heavy Dart image ops run in a background isolate — UI remains responsive.
  static Future<List<int>> cropToFace(List<int> imageBytes,
      {int targetSize = 400}) async {
    final bytes = Uint8List.fromList(imageBytes);

    // ── Web path: delegate entirely to JS face-api + fallback ─────────────
    if (kIsWeb) {
      try {
        debugPrint('SmartCropper: Web — invoking JS face-api...');
        final webResult = await cropFaceWeb(imageBytes, targetSize);
        if (webResult != null) return webResult;
        debugPrint(
            'SmartCropper Web: JS face detection failed, using center-crop.');
      } catch (e) {
        debugPrint('SmartCropper Web Error: $e');
      }
      // Fallback: decode dimensions on main thread (fast), crop in isolate
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return imageBytes;
      final side =
          decoded.width < decoded.height ? decoded.width : decoded.height;
      final cx = (decoded.width - side) ~/ 2;
      final cy = (decoded.height - side) ~/ 2;
      return compute(
        _cropAndEncodeInIsolate,
        _CropParams(bytes, cx, cy, side, targetSize),
      );
    }

    // ── Native path: ML Kit face detection (async, non-blocking) ─────────
    int cropX = 0, cropY = 0, sideLength = 0;

    try {
      // Quick dimension read to compute default center-crop (lightweight)
      final dimImage = img.decodeImage(bytes);
      if (dimImage != null) {
        sideLength =
            dimImage.width < dimImage.height ? dimImage.width : dimImage.height;
        cropX = (dimImage.width - sideLength) ~/ 2;
        cropY = (dimImage.height - sideLength) ~/ 2;
      }
    } catch (_) {}

    // ML Kit: write temp file → detect → read result → delete
    try {
      debugPrint('SmartCropper: Running ML Kit face detection...');
      final tempFile = File(
          '${Directory.systemTemp.path}/temp_face_crop_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(bytes);

      final faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          enableContours: false,
          enableLandmarks: false,
          enableClassification: false,
          performanceMode: FaceDetectorMode.fast,
        ),
      );

      final faces = await faceDetector
          .processImage(InputImage.fromFilePath(tempFile.path));
      await faceDetector.close();
      if (await tempFile.exists()) await tempFile.delete();

      if (faces.isNotEmpty) {
        final rect = faces.first.boundingBox;
        debugPrint(
            'SmartCropper: Face at (${rect.left.toInt()},${rect.top.toInt()}) ${rect.width.toInt()}x${rect.height.toInt()}');
        final faceCenterX = rect.left + rect.width / 2;
        final faceCenterY = rect.top + rect.height / 2;
        sideLength =
            ((rect.width > rect.height ? rect.width : rect.height) * 1.5)
                .toInt();

        // Clamp to original dimensions (need quick decode to get them)
        final dimChk = img.decodeImage(bytes);
        if (dimChk != null) {
          if (sideLength > dimChk.width) sideLength = dimChk.width;
          if (sideLength > dimChk.height) sideLength = dimChk.height;
          cropX = (faceCenterX - sideLength / 2)
              .toInt()
              .clamp(0, dimChk.width - sideLength);
          cropY = (faceCenterY - sideLength / 2)
              .toInt()
              .clamp(0, dimChk.height - sideLength);
        }
      } else {
        debugPrint('SmartCropper: No face found, using center-crop fallback.');
      }
    } catch (e) {
      debugPrint('SmartCropper ML Kit Error: $e — using center-crop.');
    }

    if (sideLength == 0) return imageBytes;

    // ── Background isolate: all pixel manipulation off UI thread ────────
    debugPrint('SmartCropper: Cropping in background isolate...');
    return compute(
      _cropAndEncodeInIsolate,
      _CropParams(bytes, cropX, cropY, sideLength, targetSize),
    );
  }
}
