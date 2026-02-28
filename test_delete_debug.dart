import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  // Let's print out the exact redirect URL to see if it changed.
  final fileId = 'YOUR_TEST_FILE_ID_HERE'; 
  final scriptUrl = 'https://script.google.com/macros/s/AKfycbyuSu8Hnnxkk1BlrWt_M1NlkGfmk8Ceh-uy8uPy6US7-s-kqCUekvxHGNOft_P1ecX6PQ/exec';

  print('Sending GET delete request without automatic redirects...');
  
  try {
    final client = http.Client();
    final deleteUri = Uri.parse('$scriptUrl?action=delete&fileId=$fileId');
    
    // Natively follows redirects
    final request = http.Request('GET', deleteUri)
      ..followRedirects = false;
      
    final streamed = await client.send(request);
    final response = await http.Response.fromStream(streamed);
    
    print('Initial Status: ${response.statusCode}');
    
    if (response.statusCode == 302 || response.statusCode == 303) {
      final loc = response.headers['location'];
      print('Redirects to: $loc');
      if (loc != null) {
        final r2 = await client.get(Uri.parse(loc));
        print('Final Status: ${r2.statusCode}');
        print('Final Response: ${r2.body}');
      }
    } else {
        print('No redirect! Response: ${response.body}');
    }
  } catch(e) {
    print('Error: $e');
  }
}
