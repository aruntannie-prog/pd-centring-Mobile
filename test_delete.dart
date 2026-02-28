import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final fileId = 'YOUR_TEST_FILE_ID_HERE'; // Replace with a real one
  final scriptUrl = 'https://script.google.com/macros/s/AKfycbysm0kpKx_qEncxYfrZXpkL3dGZOQMpMU6pBPDgaQ2IHtX5hRlflAYpSQsKa6RjaI8m/exec';

  print('Sending GET delete request...');
  
  try {
    final client = http.Client();
    final deleteUri = Uri.parse('$scriptUrl?action=delete&fileId=$fileId');
    
    // Natively follows redirects
    final response = await client.get(deleteUri);
    
    print('Status: ${response.statusCode}');
    print('Response: ${response.body}');
  } catch(e) {
    print('Error: $e');
  }
}
