import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

void main() async {
  final _scriptUrl = 'https://script.google.com/macros/s/AKfycbyuSu8Hnnxkk1BlrWt_M1NlkGfmk8Ceh-uy8uPy6US7-s-kqCUekvxHGNOft_P1ecX6PQ/exec';
  final _folderId = '152zUFTuiWd1AFrwFT-PUM3CGYs_YAm_W';
  
  // Create a tiny 1x1 transparent PNG payload
  final List<int> tinyPng = [
    137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0, 0, 0, 1, 8,
    6, 0, 0, 0, 31, 21, 196, 137, 0, 0, 0, 10, 73, 68, 65, 84, 120, 156, 99, 0, 1, 0, 0, 5,
    0, 1, 13, 10, 45, 180, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130
  ];
  
  final base64String = base64Encode(tinyPng);
  
  final payload = jsonEncode({
    'base64': base64String,
    'filename': 'test_upload_script.png',
    'mimeType': 'image/png',
    'folderId': _folderId,
  });

  print('Sending POST upload request...');
  
  final client = http.Client();
  final request = http.Request('POST', Uri.parse(_scriptUrl))
    ..headers['Content-Type'] = 'text/plain'
    ..body = payload
    ..followRedirects = false; // Test native behavior

  try {
    final streamed = await client.send(request);
    final response = await http.Response.fromStream(streamed);
    
    print('Initial Status: ${response.statusCode}');
    String body = response.body;
    
    if (response.statusCode == 302 || response.statusCode == 303) {
      final loc = response.headers['location'];
      print('Redirects to: $loc');
      if (loc != null) {
        final r2 = await client.get(Uri.parse(loc));
        print('Final Status: ${r2.statusCode}');
        body = r2.body;
      }
    }
    
    print('Response Body: $body');
  } catch(e) {
    print('Error: $e');
  } finally {
    client.close();
  }
}
