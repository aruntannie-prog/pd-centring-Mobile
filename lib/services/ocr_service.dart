import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class OcrResult {
  final String name;
  final String address;
  const OcrResult({required this.name, required this.address});
  bool get hasName => name.isNotEmpty;
  bool get hasAddress => address.isNotEmpty;
  bool get hasData => hasName || hasAddress;
}

class OcrService {
  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

  /// Extracts customer name and address from an Indian address proof document image.
  /// Returns null if the API key is not configured, or if extraction fails.
  static Future<OcrResult?> extractFromImage(
      Uint8List imageBytes, String mimeType) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (apiKey.isEmpty) return null;

    final base64Image = base64Encode(imageBytes);

    const prompt = '''You are an OCR assistant for Indian address proof documents.
The document could be an Aadhaar card, PAN card, Voter ID, Gas bill, Electricity bill, or Water bill.

Extract ONLY the following from this document image:
1. Full name of the person/customer (as printed on the document)
2. Complete address (street, city, state, pincode as shown)

Return ONLY a valid JSON object with exactly these two keys, no markdown, no explanation:
{"name": "...", "address": "..."}

Rules:
- Aadhaar: Name is prominently printed, address is the registered address
- PAN card: Extract the name; address is usually not present so use ""
- Utility bills: Extract the consumer/subscriber name and service address
- Do not invent or guess — use empty string "" if a field is not clearly visible
- For Tamil/regional scripts, also include the English transliteration if shown''';

    final body = json.encode({
      'contents': [
        {
          'parts': [
            {
              'inline_data': {
                'mime_type': mimeType,
                'data': base64Image,
              }
            },
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.1,
        'maxOutputTokens': 256,
      }
    });

    try {
      final response = await http
          .post(
            Uri.parse('$_endpoint?key=$apiKey'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        print('OcrService: HTTP ${response.statusCode}: ${response.body}');
        return null;
      }

      final data = json.decode(response.body);
      final rawText =
          data['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
      if (rawText == null || rawText.isEmpty) return null;

      // Strip markdown code fences if Gemini wrapped the JSON
      String cleaned = rawText.trim();
      cleaned = cleaned
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();

      // Find first JSON object in the response
      final jsonMatch =
          RegExp(r'\{[^{}]*\}', dotAll: true).firstMatch(cleaned);
      if (jsonMatch == null) return null;

      final parsed = json.decode(jsonMatch.group(0)!) as Map<String, dynamic>;
      final name = (parsed['name'] ?? '').toString().trim();
      final address = (parsed['address'] ?? '').toString().trim();

      return OcrResult(name: name, address: address);
    } catch (e) {
      print('OcrService: Error extracting from document: $e');
      return null;
    }
  }
}
