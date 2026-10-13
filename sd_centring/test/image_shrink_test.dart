// Images are made smaller for upload without visible loss.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sd_centring/services/image_shrink.dart';

Uint8List photo(int w, int h, {int quality = 100}) {
  final image = img.Image(width: w, height: h);
  // Some detail, so the encoder has real work to do.
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      image.setPixelRgb(x, y, (x * 7) % 256, (y * 5) % 256, (x + y) % 256);
    }
  }
  return img.encodeJpg(image, quality: quality);
}

void main() {
  test(
    'a big camera photo is reduced to 2000 px and gets much smaller',
    () async {
      final big = photo(4000, 3000);
      final out = await shrinkImage(
        big,
        contentType: 'image/jpeg',
        maxSide: 2000,
      );
      final decoded = img.decodeJpg(out.bytes)!;
      expect(decoded.width, 2000);
      expect(decoded.height, 1500);
      expect(out.contentType, 'image/jpeg');
      expect(out.bytes.length, lessThan(big.length ~/ 2));
    },
  );

  test('portrait photos keep their shape', () async {
    final out = await shrinkImage(
      photo(1500, 3000),
      contentType: 'image/jpeg',
      maxSide: 2000,
    );
    final decoded = img.decodeJpg(out.bytes)!;
    expect(decoded.height, 2000);
    expect(decoded.width, 1000);
  });

  test('a small image is left exactly as it was', () async {
    final small = photo(800, 600, quality: 70);
    final out = await shrinkImage(
      small,
      contentType: 'image/jpeg',
      maxSide: 2000,
    );
    expect(out.bytes, same(small));
  });

  test('files under the skip size are not touched at all', () async {
    final big = photo(3000, 2000);
    final out = await shrinkImage(
      big,
      contentType: 'image/jpeg',
      maxSide: 1000,
      skipBelowBytes: big.length + 1,
    );
    expect(out.bytes, same(big));
  });

  test(
    'the phone rotation flag is applied, so photos are not sideways',
    () async {
      final image = img.Image(width: 400, height: 200);
      image.exif.imageIfd.orientation = 6; // rotate 90°
      final bytes = img.encodeJpg(image);
      final out = await shrinkImage(
        bytes,
        contentType: 'image/jpeg',
        maxSide: 2000,
      );
      final decoded = img.decodeJpg(out.bytes)!;
      expect(decoded.width, 200);
      expect(decoded.height, 400);
    },
  );

  test('transparent PNGs stay PNG', () async {
    final image = img.Image(width: 3000, height: 1000, numChannels: 4);
    image.clear(img.ColorRgba8(255, 0, 0, 0));
    final out = await shrinkImage(
      img.encodePng(image),
      contentType: 'image/png',
      maxSide: 2000,
    );
    expect(out.contentType, 'image/png');
    expect(img.decodePng(out.bytes)!.width, 2000);
  });

  test('something that is not an image is returned unchanged', () async {
    final junk = Uint8List.fromList(List.filled(300 * 1024, 7));
    final out = await shrinkImage(
      junk,
      contentType: 'image/jpeg',
      maxSide: 2000,
    );
    expect(out.bytes, same(junk));
  });

  test('thumbnails are small', () async {
    final thumb = await makeThumbnail(photo(1024, 1024));
    final decoded = img.decodeJpg(thumb!)!;
    expect(decoded.width, 256);
    expect(thumb.length, lessThan(40 * 1024));
    expect(await makeThumbnail(Uint8List.fromList([1, 2, 3])), isNull);
  });
}
