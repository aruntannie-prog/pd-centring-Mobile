import 'dart:io';
import 'package:gsheets/gsheets.dart';
import 'lib/secrets.dart';

void main() async {
  final ss = await GSheets(googleCredentials).spreadsheet(sheetsId);
  final s = ss.worksheetByTitle('Customers');
  final mappedRows = await s!.values.map.allRows();
  if (mappedRows == null) return;

  for (var r in mappedRows) {
    print('Customer: ${r['name']}');
    print('  - Photo: "${r['profilePhotoUrl']}"');
    print('  - Doc: "${r['addressProofUrl']}"');
  }
  exit(0);
}
