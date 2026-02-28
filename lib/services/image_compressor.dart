import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;

// Top-level params for compute() isolate
class _CompressParams {
  final Uint8List bytes;
  final int maxWidth, quality;
  const _CompressParams(this.bytes, this.maxWidth, this.quality);
}

/// Top-level function — runs in a background isolate via compute().
Uint8List _compressInIsolate(_CompressParams p) {
  final decoded = img.decodeImage(p.bytes);
  if (decoded == null) return p.bytes;
  img.Image output = decoded;
  if (decoded.width > p.maxWidth) {
    output = img.copyResize(decoded, width: p.maxWidth, maintainAspect: true);
  }
  return Uint8List.fromList(img.encodeJpg(output, quality: p.quality));
}

/// Compresses images before upload. Target: 300KB–800KB, max width 1280px.
/// All heavy Dart image ops run in a background isolate — UI stays responsive.
class ImageCompressor {
  static const int _maxWidth = 1280;
  static const int _quality = 82;

  static Future<Uint8List> compress(
    Uint8List bytes, {
    int maxWidth = _maxWidth,
    int quality = _quality,
  }) async {
    try {
      if (kIsWeb) {
        // Web: dart:image runs in background isolate to avoid UI blocking
        return await compute(
          _compressInIsolate,
          _CompressParams(bytes, maxWidth, quality),
        );
      } else {
        // Native: flutter_image_compress uses native codec off UI thread
        final result = await FlutterImageCompress.compressWithList(
          bytes,
          minWidth: maxWidth,
          minHeight: 0,
          quality: quality,
          format: CompressFormat.jpeg,
          keepExif: false,
        );
        debugPrint(
            'ImageCompressor: ${bytes.length ~/ 1024}KB → ${result.length ~/ 1024}KB');
        return result;
      }
    } catch (e) {
      debugPrint('ImageCompressor: Error, returning original: $e');
      return bytes;
    }
  }
}
