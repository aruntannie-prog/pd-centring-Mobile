import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// Top-level function — runs in background isolate via compute().
// base64Encode of large images takes 50-500ms, blocking the UI if done inline.
String _encodeBase64(Uint8List bytes) => base64Encode(bytes);

class GoogleDriveApi {
  static const _folderId = '152zUFTuiWd1AFrwFT-PUM3CGYs_YAm_W';
  static const _scriptUrl =
      'https://script.google.com/macros/s/AKfycbyuSu8Hnnxkk1BlrWt_M1NlkGfmk8Ceh-uy8uPy6US7-s-kqCUekvxHGNOft_P1ecX6PQ/exec';

  static Future<void> init() async {
    debugPrint('GoogleDriveApi: Using Apps Script Webhook.');
  }

  /// Returns a direct `thumbnail?id=...` URL ready to display.
  /// Base64 encoding runs in a background isolate — UI stays responsive.
  static Future<String?> uploadFile({
    required String fileName,
    required List<int> bytes,
    String? mimeType,
    int maxRetries = 3,
  }) async {
    // Resolve MIME type
    String resolvedMimeType = mimeType ?? 'application/octet-stream';
    if (mimeType == null) {
      final ext = fileName.split('.').last.toLowerCase();
      if (ext == 'png')
        resolvedMimeType = 'image/png';
      else if (ext == 'jpg' || ext == 'jpeg')
        resolvedMimeType = 'image/jpeg';
      else if (ext == 'gif')
        resolvedMimeType = 'image/gif';
      else if (ext == 'webp')
        resolvedMimeType = 'image/webp';
      else if (ext == 'heic')
        resolvedMimeType = 'image/heic';
      else if (ext == 'pdf') resolvedMimeType = 'application/pdf';
    }

    // ─── base64 encode off UI thread ──────────────────────────────────────
    // On native: compute() spawns a true background isolate.
    // On web: compute() on web runs synchronously BUT imageQuality:40 means
    //   bytes are small (~50-100KB), so encoding takes <10ms — acceptable.
    final base64String =
        await compute(_encodeBase64, Uint8List.fromList(bytes));

    final payload = jsonEncode({
      'base64': base64String,
      'filename': fileName,
      'mimeType': resolvedMimeType,
      'folderId': _folderId,
    });

      for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('GoogleDriveApi: 🚀 [Attempt $attempt] Starting upload for $fileName');
        print('GoogleDriveApi: 📦 Payload size: ${(payload.length / 1024).toStringAsFixed(2)} KB');
        
        final uri = Uri.parse(_scriptUrl);
        
        // 1. Send the initial POST request. We disable followRedirects because 
        // the http package does not handle POST -> 302 -> GET bridging well.
        final client = http.Client();
        final request = http.Request('POST', uri)
          ..headers['Content-Type'] = 'text/plain'
          ..body = payload
          ..followRedirects = false; // Key fix for native mobile

        final streamedResponse = await client.send(request).timeout(const Duration(seconds: 90));
        final response = await http.Response.fromStream(streamedResponse);
        
        print('GoogleDriveApi: 📥 Initial Response Status: ${response.statusCode}');
        
        String body = response.body;
        
        // 2. Google Apps Script almost always returns 302 on success, redirecting
        // to a temporary googleusercontent.com URL containing the JSON response.
        if (response.statusCode == 302 || response.statusCode == 303) {
          final redirectUrl = response.headers['location'];
          if (redirectUrl != null) {
            print('GoogleDriveApi: 🔀 Following redirect to fetch JSON response...');
            final redirectResponse = await client.get(Uri.parse(redirectUrl));
            body = redirectResponse.body;
            print('GoogleDriveApi: 📥 Redirect Response Status: ${redirectResponse.statusCode}');
          } else {
            print('GoogleDriveApi: ❌ 302 Response missing location header.');
          }
        }
        
        client.close();

        // 3. Process the final body (whether it was 200 directly or via 302 GET)
        if (body.isNotEmpty) {
          print('GoogleDriveApi: 📄 Response Body (start): ${body.length > 300 ? body.substring(0, 300) : body}');
          
          if (body.contains('<!DOCTYPE html>') || body.contains('<html')) {
             print('GoogleDriveApi: ⚠️ Received HTML instead of JSON. Webhook might be failing or requiring login.');
          } else {
            try {
              final result = jsonDecode(body);
              if (result['success'] == true) {
                final fileId = result['fileId'] as String?;
                if (fileId != null && fileId.isNotEmpty) {
                  final isImage = ['jpg', 'jpeg', 'png', 'webp', 'gif', 'heic']
                      .contains(fileName.split('.').last.toLowerCase());
                  final directUrl = isImage
                      ? 'https://drive.google.com/uc?export=view&id=$fileId'
                      : 'https://drive.google.com/uc?export=download&id=$fileId';
                  print('GoogleDriveApi: ✅ SUCCESS: $directUrl');
                  return directUrl;
                }
              } else {
                print('GoogleDriveApi: ❌ Webhook Error Message: ${result['error']}');
              }
            } catch (je) {
              print('GoogleDriveApi: ❌ JSON Parse Error on body of length ${body.length}');
            }
          }
        } else {
           print('GoogleDriveApi: ❌ Server returned empty body.');
        }

      } catch (e) {
        print('GoogleDriveApi: ❌ Exception on attempt $attempt: $e');
      }

      if (attempt < maxRetries) {
        final delay = Duration(seconds: attempt * 3);
        print('GoogleDriveApi: ⏳ Waiting ${delay.inSeconds}s before retry...');
        await Future.delayed(delay);
      }
    }

    print(
        'GoogleDriveApi: 🚨 All $maxRetries attempts failed for $fileName');
    return null;
  }

  /// Triggers a remote deletion of a file by URL via the Apps Script Webhook.
  static Future<bool> deleteFile(String fileUrl) async {
    final fileId = _extractFileId(fileUrl);
    if (fileId == null || fileId.isEmpty) return false;

    final payload = jsonEncode({
      'action': 'delete',
      'fileId': fileId,
    });

    final uri = Uri.parse(_scriptUrl);
    final client = http.Client();

    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        final deleteUri = Uri.parse('$_scriptUrl?action=delete&fileId=$fileId');
        
        // Use a simple GET request logic. http.get natively follows GET redirects.
        final response = await client.get(deleteUri).timeout(const Duration(seconds: 45));

        if (response.body.isNotEmpty) {
          try {
            final result = jsonDecode(response.body);
            if (result['success'] == true) {
              print('GoogleDriveApi: ✅ Successfully trashed $fileId');
              client.close();
              return true;
            } else {
              print('GoogleDriveApi: ❌ Delete failed: ${result['error']}');
            }
          } catch (_) {
            print('GoogleDriveApi: ❌ JSON Parse Error on delete response: ${response.body}');
          }
        }
      } catch (e) {
        print('GoogleDriveApi: ❌ Exception on delete attempt $attempt: $e');
      }

      if (attempt < 3) {
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }

    client.close();
    return false;
  }

  /// Extracts Drive file ID from any Drive URL format.
  static String? _extractFileId(String url) {
    if (url.contains('/d/')) return url.split('/d/')[1].split('/')[0];
    if (url.contains('id=')) return url.split('id=')[1].split('&')[0];
    return null;
  }
}
