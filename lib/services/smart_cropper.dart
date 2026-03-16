import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'smart_cropper_stub.dart'
    if (dart.library.html) 'smart_cropper_web.dart'
    if (dart.library.io) 'smart_cropper_native.dart';

class SmartCropper {
  /// Crops the given image bytes to a square around the detected face.
  static Future<List<int>> cropToFace(List<int> imageBytes,
      {int targetSize = 400}) async {
    final bytes = Uint8List.fromList(imageBytes);

    if (kIsWeb) {
      try {
        debugPrint('SmartCropper: Web — invoking JS face-api...');
        final webResult = await cropFaceWeb(imageBytes, targetSize);
        if (webResult != null) return webResult;
        debugPrint('SmartCropper Web: JS face detection failed, using center-crop.');
      } catch (e) {
        debugPrint('SmartCropper Web Error: $e');
      }
      
      // Fallback: decode dimensions on main thread (fast), crop in isolate
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return imageBytes;
      final side = decoded.width < decoded.height ? decoded.width : decoded.height;
      final cx = (decoded.width - side) ~/ 2;
      final cy = (decoded.height - side) ~/ 2;
      return compute(
        _cropAndEncodeInIsolate,
        _CropParams(bytes, cx, cy, side, targetSize),
      );
    }

    // Native implementation handled by conditional import
    // Note: We need a common interface or a way to call the native logic.
    // Instead of a class, let's use a function based delegate if needed, 
    // but for now let's use the NativeCropper if available.
    
    // In Dart, we can't easily call a class that only exists in one branch 
    // unless we use a common interface. 
    // Let's simplify: SmartCropper will contain the common "Fallback" logic 
    // and delegate the "Face Detection" logic.

    return nativeCropToFace(imageBytes, targetSize);
  }
}

// These must be defined in the stub/web/native files or handled here if they don't use dart:io
class _CropParams {
  final Uint8List imageBytes;
  final int cropX, cropY, sideLength, targetSize;
  const _CropParams(this.imageBytes, this.cropX, this.cropY, this.sideLength,
      this.targetSize);
}

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

// This function will be defined in smart_cropper_stub.dart, smart_cropper_web.dart, and smart_cropper_native.dart
// But we can only have one "real" definition if we use conditional imports like this.
// Wait, the standard way is to have the same function signature in all conditionally imported files.

