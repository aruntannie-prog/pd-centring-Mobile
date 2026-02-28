import 'dart:js_util' as js_util;
import 'package:js/js.dart';
import 'dart:convert';

@JS('autoCropFaceBase64')
external dynamic autoCropFaceBase64Js(String base64Image, int targetSize);

Future<List<int>?> cropFaceWeb(List<int> imageBytes, int targetSize) async {
  try {
    print('SmartCropperWeb: Encoding image to Base64...');
    final base64Str = base64Encode(imageBytes);
    print('SmartCropperWeb: Invoking autoCropFaceBase64JS...');
    final promise = autoCropFaceBase64Js(base64Str, targetSize);
    print('SmartCropperWeb: Waiting for JS Promise...');
    final String resultBase64 = await js_util.promiseToFuture(promise);
    print('SmartCropperWeb: Decoding result Base64...');
    return base64Decode(resultBase64);
  } catch (e) {
    print('SmartCropperWeb Error: $e');
    return null;
  }
}
