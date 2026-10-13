import 'dart:async';
import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';

import '../config/document_ai.dart';
import '../models/customer.dart';

/// What could be read from an ID or address proof. Anything the document
/// does not show is left empty (a PAN card has no address, for example).
class DocumentDetails {
  const DocumentDetails({
    this.kind = '',
    this.name = '',
    this.address = '',
    this.sample = false,
  });

  /// One of [documentKinds], or empty when unsure.
  final String kind;
  final String name;
  final String address;

  /// Demo mode: made-up values, not read from the file.
  final bool sample;

  bool get isEmpty => name.isEmpty && address.isEmpty;
}

class DocumentReadException implements Exception {
  DocumentReadException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Reads the name and address from a photo or PDF of a document.
abstract class DocumentReader {
  /// False when reading is switched off; the form then skips it.
  bool get available;

  /// Throws [DocumentReadException] with a message for the user.
  Future<DocumentDetails> read(Uint8List bytes, String contentType);
}

class NoDocumentReader implements DocumentReader {
  const NoDocumentReader();

  @override
  bool get available => false;

  @override
  Future<DocumentDetails> read(Uint8List bytes, String contentType) =>
      throw DocumentReadException('Reading documents is switched off.');
}

/// Demo mode has no Firebase, so it shows how the feature behaves with
/// clearly marked sample values.
class DemoDocumentReader implements DocumentReader {
  const DemoDocumentReader();

  @override
  bool get available => true;

  @override
  Future<DocumentDetails> read(Uint8List bytes, String contentType) async {
    checkReadable(bytes, contentType);
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    return const DocumentDetails(
      kind: 'Aadhaar',
      name: 'Selvam Kumar',
      address: '12, Gandhi Street, Selaiyur, Chennai, Tamil Nadu 600073',
      sample: true,
    );
  }
}

/// Uses Gemini through Firebase AI Logic. The document goes straight from
/// the phone to Google over Firebase's own connection: no API key is kept
/// in the app and no server of our own is needed. Only the name, address
/// and type of document are asked for; ID numbers are never extracted or
/// stored.
class GeminiDocumentReader implements DocumentReader {
  GeminiDocumentReader()
    : _model =
          (DocumentAi.useAgentPlatform
                  ? FirebaseAI.agentPlatform()
                  : FirebaseAI.googleAI())
              .generativeModel(
                model: DocumentAi.model,
                systemInstruction: Content.system(documentPrompt),
                generationConfig: GenerationConfig(
                  temperature: 0,
                  responseMimeType: 'application/json',
                  responseSchema: Schema.object(
                    properties: {
                      'kind': Schema.enumString(enumValues: documentKinds),
                      'name': Schema.string(),
                      'address': Schema.string(),
                    },
                  ),
                ),
              );

  final GenerativeModel _model;

  @override
  bool get available => true;

  @override
  Future<DocumentDetails> read(Uint8List bytes, String contentType) async {
    checkReadable(bytes, contentType);
    try {
      final response = await _model
          .generateContent([
            Content.multi([
              InlineDataPart(contentType, bytes),
              TextPart('Read this document.'),
            ]),
          ])
          .timeout(const Duration(seconds: 45));
      final text = response.text;
      if (text == null || text.trim().isEmpty) {
        throw DocumentReadException('Nothing could be read from this file.');
      }
      return parseDocumentDetails(text);
    } on DocumentReadException {
      rethrow;
    } on TimeoutException {
      throw DocumentReadException(
        'Reading took too long. Check the internet connection.',
      );
    } on ServiceApiNotEnabled {
      throw DocumentReadException(
        'Document reading is not switched on yet. Ask the owner to enable '
        'Firebase AI Logic (see README).',
      );
    } on QuotaExceeded {
      throw DocumentReadException(
        'Document reading limit reached for now. Type the details instead.',
      );
    } catch (e) {
      debugPrint('GeminiDocumentReader: $e');
      throw DocumentReadException(
        'Could not read this document. Type the details instead.',
      );
    }
  }
}

/// Instructions for the model. Kept here so they can be reviewed.
const documentPrompt = '''
You read Indian identity and address documents: Aadhaar cards (front or
back, or e-Aadhaar), PAN cards, voter ID cards, driving licences, and
utility bills such as electricity (EB / TNEB), water, gas, telephone or
broadband bills, and bank statements.

Return JSON with:
- kind: the type of document. Use "Utility bill" for any bill or bank
  statement, "Other" if it is none of the listed types.
- name: the full name of the person the document belongs to (card holder,
  consumer, account holder), as printed. Write it in English letters; if it
  is printed only in another script such as Tamil, transliterate it.
- address: that person's postal address in English, on one line with parts
  separated by ", ", ending with the PIN code if shown. Leave out relation
  prefixes and the relative's name (S/O, D/O, W/O, C/O and the name after
  them).

Leave a field as an empty string when the document does not show it (a
PAN card has no address) or it cannot be read clearly. Never guess.
Never return ID numbers (Aadhaar, VID, PAN, voter ID, licence, consumer or
account numbers), dates of birth, gender, phone numbers or e-mail.
''';

/// Rejects files that cannot be read before spending a request on them.
void checkReadable(Uint8List bytes, String contentType) {
  if (contentType == 'application/pdf' && isEncryptedPdf(bytes)) {
    throw DocumentReadException(
      'This PDF is password-protected (e-Aadhaar PDFs usually are), so it '
      'cannot be read. Type the details, or add a photo or screenshot of '
      'the card instead.',
    );
  }
}

/// Password-protected PDFs carry an /Encrypt entry.
bool isEncryptedPdf(Uint8List bytes) {
  const needle = [0x2F, 0x45, 0x6E, 0x63, 0x72, 0x79, 0x70, 0x74]; // /Encrypt
  outer:
  for (var i = 0; i <= bytes.length - needle.length; i++) {
    for (var j = 0; j < needle.length; j++) {
      if (bytes[i + j] != needle[j]) continue outer;
    }
    return true;
  }
  return false;
}

/// Parses the model's JSON reply. Tolerates code fences and missing or
/// wrongly typed fields; unknown kinds become empty.
DocumentDetails parseDocumentDetails(String text) {
  var t = text.trim();
  if (t.startsWith('```')) {
    t = t.replaceFirst(RegExp(r'^```[a-zA-Z]*\s*'), '');
    t = t.replaceFirst(RegExp(r'\s*```$'), '');
  }
  final Object? decoded;
  try {
    decoded = jsonDecode(t);
  } catch (_) {
    throw DocumentReadException('Nothing could be read from this file.');
  }
  if (decoded is! Map) {
    throw DocumentReadException('Nothing could be read from this file.');
  }
  String str(Object? v) => v is String ? v : '';
  final kind = str(decoded['kind']).trim();
  return DocumentDetails(
    kind: documentKinds.contains(kind) ? kind : '',
    name: tidyPersonName(str(decoded['name'])),
    address: tidyAddress(str(decoded['address'])),
  );
}

/// "RAVI  KUMAR" → "Ravi Kumar"; mixed-case names are kept as printed.
/// Initials stay capital: "R. KUMAR" → "R. Kumar".
String tidyPersonName(String raw) {
  final s = tidyText(raw.replaceAll(RegExp(r'[\r\n]+'), ' '));
  if (s.isEmpty || s != s.toUpperCase()) return s;
  return s
      .split(' ')
      .map((w) {
        if (w.length <= 1) return w;
        if (RegExp(r'^[A-Z]\.$').hasMatch(w)) return w; // initial "R."
        return w[0] + w.substring(1).toLowerCase();
      })
      .join(' ');
}

/// One line, single spaces, no stray or doubled commas.
String tidyAddress(String raw) {
  var s = raw.replaceAll(RegExp(r'\s*[\r\n]+\s*'), ', ');
  s = s.replaceAll(RegExp(r'[ \t]+'), ' ');
  s = s.replaceAll(RegExp(r'\s*,\s*(,\s*)*'), ', ');
  s = s.replaceAll(RegExp(r'^[,\s]+|[,\s]+$'), '');
  return s;
}
