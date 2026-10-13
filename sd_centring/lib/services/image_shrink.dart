import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// An image ready to upload.
class ShrunkImage {
  const ShrunkImage(this.bytes, this.contentType);

  final Uint8List bytes;
  final String contentType;
}

/// Makes a photo smaller for upload without visible loss:
///
/// * the long side is reduced to [maxSide] pixels only if it is bigger
///   (2000 px keeps the small print on an ID card or bill sharp),
/// * it is saved as JPEG at [quality] (85 is visually lossless),
/// * the phone's rotation flag is applied, so photos never end up sideways,
/// * images with transparency stay PNG,
/// * if the result would not be smaller, the original is kept.
///
/// Files under [skipBelowBytes] are returned untouched. Runs on a
/// background isolate so the screen does not freeze.
Future<ShrunkImage> shrinkImage(
  Uint8List bytes, {
  required String contentType,
  required int maxSide,
  int quality = 85,
  int skipBelowBytes = 0,
}) async {
  if (bytes.length < skipBelowBytes) return ShrunkImage(bytes, contentType);
  try {
    final out = await _run(
      _Job(bytes, contentType, maxSide, quality, keepIfLarger: true),
    );
    return out ?? ShrunkImage(bytes, contentType);
  } catch (e) {
    debugPrint('shrinkImage: kept original: $e');
    return ShrunkImage(bytes, contentType);
  }
}

/// Small square-ish preview for lists (about 15 KB). Null if the image
/// cannot be read.
Future<Uint8List?> makeThumbnail(Uint8List bytes, {int side = 256}) async {
  try {
    final out = await _run(
      _Job(bytes, 'image/jpeg', side, 80, keepIfLarger: false),
    );
    return out?.bytes;
  } catch (e) {
    debugPrint('makeThumbnail: $e');
    return null;
  }
}

/// Small images are quicker to do right here than to hand to an isolate.
Future<ShrunkImage?> _run(_Job job) async =>
    job.bytes.length < 150 * 1024 ? _shrink(job) : compute(_shrink, job);

class _Job {
  const _Job(
    this.bytes,
    this.contentType,
    this.maxSide,
    this.quality, {
    required this.keepIfLarger,
  });

  final Uint8List bytes;
  final String contentType;
  final int maxSide;
  final int quality;
  final bool keepIfLarger;
}

ShrunkImage? _shrink(_Job job) {
  final decoded = img.decodeImage(job.bytes);
  if (decoded == null) return null;
  var image = img.bakeOrientation(decoded);
  final longSide = math.max(image.width, image.height);
  final resized = longSide > job.maxSide;
  if (resized) {
    image = image.width >= image.height
        ? img.copyResize(
            image,
            width: job.maxSide,
            interpolation: img.Interpolation.average,
          )
        : img.copyResize(
            image,
            height: job.maxSide,
            interpolation: img.Interpolation.average,
          );
  }
  final ShrunkImage out;
  if (image.hasAlpha && _usesAlpha(image)) {
    out = ShrunkImage(img.encodePng(image, level: 6), 'image/png');
  } else {
    out = ShrunkImage(img.encodeJpg(image, quality: job.quality), 'image/jpeg');
  }
  // Rotation was applied, so keep the result if it was rotated even when
  // it is not smaller.
  final rotated =
      decoded.exif.imageIfd.orientation != null &&
      decoded.exif.imageIfd.orientation != 1;
  if (job.keepIfLarger &&
      !resized &&
      !rotated &&
      out.bytes.length >= job.bytes.length) {
    return null;
  }
  return out;
}

/// True if any pixel is not fully opaque (sampled for speed).
bool _usesAlpha(img.Image image) {
  final stepX = math.max(1, image.width ~/ 64);
  final stepY = math.max(1, image.height ~/ 64);
  for (var y = 0; y < image.height; y += stepY) {
    for (var x = 0; x < image.width; x += stepX) {
      if (image.getPixel(x, y).a < image.maxChannelValue) return true;
    }
  }
  return false;
}
