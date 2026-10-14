// The Gemini document reader against a fake HTTP server: checks the request
// the app sends (model, file, instructions, JSON schema) and how it handles
// real-shaped replies and API errors. No network is used.
import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sd_centring/config/document_ai.dart';
import 'package:sd_centring/services/document_reader.dart';

late FirebaseApp app;

http.Response gemini(String text) => http.Response(
  jsonEncode({
    'candidates': [
      {
        'content': {
          'role': 'model',
          'parts': [
            {'text': text},
          ],
        },
        'finishReason': 'STOP',
      },
    ],
  }),
  200,
  headers: {'content-type': 'application/json'},
);

http.Response apiError(int code, String status, String message) =>
    http.Response(
      jsonEncode({
        'error': {'code': code, 'status': status, 'message': message},
      }),
      code,
      headers: {'content-type': 'application/json'},
    );

final pdf = Uint8List.fromList(utf8.encode('%PDF-1.4\n1 0 obj\n%%EOF'));

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    app = await Firebase.initializeApp(
      name: 'reader-test',
      options: const FirebaseOptions(
        apiKey: 'test-key',
        appId: '1:123:android:abc',
        messagingSenderId: '123',
        projectId: 'demo-sd-centring',
      ),
    );
  });

  test('sends the file, the instructions and the JSON schema', () async {
    late http.Request sent;
    final reader = GeminiDocumentReader(
      app: app,
      httpClient: MockClient((req) async {
        sent = req;
        return gemini('{"kind":"PAN","name":"RAVI KUMAR"}');
      }),
    );
    final d = await reader.read(pdf, 'application/pdf');

    expect(sent.method, 'POST');
    expect(sent.url.toString(), contains(DocumentAi.model));
    expect(sent.url.toString(), contains('generateContent'));
    final body = jsonDecode(sent.body) as Map<String, dynamic>;
    final parts = (body['contents'] as List).single['parts'] as List;
    final inline = parts.firstWhere((p) => p.containsKey('inlineData'));
    expect(inline['inlineData']['mimeType'], 'application/pdf');
    expect(base64Decode(inline['inlineData']['data'] as String), pdf);
    final instructions = jsonEncode(body['systemInstruction']);
    expect(instructions, contains('Never return addresses'));
    final config = body['generationConfig'] as Map<String, dynamic>;
    expect(config['responseMimeType'], 'application/json');
    expect(config['temperature'], 0);
    final schema = jsonEncode(config['responseSchema']);
    expect(schema, contains('name'));
    expect(schema, isNot(contains('address')));

    expect(d.kind, 'PAN');
    expect(d.name, 'Ravi Kumar');
  });

  test('an address in the reply can never reach the form', () async {
    final reader = GeminiDocumentReader(
      app: app,
      httpClient: MockClient(
        (_) async => gemini(
          '{"kind":"Utility bill","name":"Selvam","address":"Site 4, OMR"}',
        ),
      ),
    );
    final d = await reader.read(pdf, 'application/pdf');
    expect(d.name, 'Selvam');
    expect(d.kind, 'Utility bill');
  });

  test('a reply with no name comes back empty, not invented', () async {
    final reader = GeminiDocumentReader(
      app: app,
      httpClient: MockClient((_) async => gemini('{"kind":"Other","name":""}')),
    );
    final d = await reader.read(pdf, 'application/pdf');
    expect(d.isEmpty, isTrue);
  });

  test('a password-protected PDF is refused before any request', () async {
    var calls = 0;
    final reader = GeminiDocumentReader(
      app: app,
      httpClient: MockClient((_) async {
        calls++;
        return gemini('{}');
      }),
    );
    final locked = Uint8List.fromList(
      utf8.encode('%PDF-1.7 trailer << /Encrypt 5 0 R >>'),
    );
    await expectLater(
      reader.read(locked, 'application/pdf'),
      throwsA(isA<DocumentReadException>()),
    );
    expect(calls, 0);
  });

  test('API switched off in Firebase gives a setup message', () async {
    const text =
        'Firebase AI Logic API has not been used in project 123 before or '
        'it is disabled. Enable it by visiting the console, then retry.';
    for (final response in [
      // Google's full error, with the detail block the SDK recognises.
      http.Response(
        jsonEncode({
          'error': {
            'code': 403,
            'status': 'PERMISSION_DENIED',
            'message': text,
            'details': [
              {
                '@type': 'type.googleapis.com/google.rpc.ErrorInfo',
                'reason': 'SERVICE_DISABLED',
                'metadata': {
                  'service': 'firebasevertexai.googleapis.com',
                  'consumer': 'projects/123',
                },
              },
            ],
          },
        }),
        403,
        headers: {'content-type': 'application/json'},
      ),
      // The same error without details.
      apiError(403, 'PERMISSION_DENIED', text),
    ]) {
      final reader = GeminiDocumentReader(
        app: app,
        httpClient: MockClient((_) async => response),
      );
      await expectLater(
        reader.read(pdf, 'application/pdf'),
        throwsA(
          isA<DocumentReadException>().having(
            (e) => e.message,
            'message',
            contains('not switched on'),
          ),
        ),
      );
    }
  });

  test('quota exceeded asks to type the name instead', () async {
    final reader = GeminiDocumentReader(
      app: app,
      httpClient: MockClient(
        (_) async => apiError(
          429,
          'RESOURCE_EXHAUSTED',
          'Quota exceeded for quota metric',
        ),
      ),
    );
    await expectLater(
      reader.read(pdf, 'application/pdf'),
      throwsA(
        isA<DocumentReadException>().having(
          (e) => e.message,
          'message',
          contains('limit reached'),
        ),
      ),
    );
  });

  test('a server error or garbage reply is reported, not crashed on', () async {
    for (final response in [
      apiError(500, 'INTERNAL', 'boom'),
      gemini('this is not json'),
      http.Response('<html>proxy error</html>', 502),
    ]) {
      final reader = GeminiDocumentReader(
        app: app,
        httpClient: MockClient((_) async => response),
      );
      await expectLater(
        reader.read(pdf, 'application/pdf'),
        throwsA(isA<DocumentReadException>()),
        reason: response.body,
      );
    }
  });
}
