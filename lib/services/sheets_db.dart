import 'dart:convert';
import 'package:gsheets/gsheets.dart';
import '../models/bill.dart';
import '../models/customer.dart';
import '../secrets.dart';

class SheetsApi {
  static final _creds = googleCredentials;
  static final _spreadsheetId = sheetsId;
  static final _gsheets = GSheets(_creds);
  static Worksheet? _billsSheet;
  static Worksheet? _customersSheet;
  static Worksheet? _suggestionsSheet;

  static Future<void> init() async {
    try {
      final ss = await _gsheets.spreadsheet(_spreadsheetId);
      print(
          'SheetsApi: Available sheets: ${ss.sheets.map((w) => w.title).toList()}');

      final s1 = ss.worksheetByTitle('Sheet1');
      if (s1 != null) {
        final rows = await s1.values.allRows();
        print('SheetsApi: Sheet1 has ${rows.length} rows');
        if (rows.length > 0) print('SheetsApi: Sheet1 Row 1: ${rows[0]}');
      }

      var sheet = ss.worksheetByTitle('Bills');
      sheet ??= await ss.addWorksheet('Bills');
      _billsSheet = sheet;

      // Standard headers we expect
      final billHeaders = [
        'id',
        'billNumber',
        'type',
        'customerName',
        'customerId',
        'site',
        'billDate',
        'branch',
        'materials'
      ];
      final customerHeaders = [
        'id',
        'name',
        'phone',
        'secondaryPhone',
        'address',
        'site',
        'gstNumber',
        'referBy',
        'billCount',
        'isActive',
        'profilePhotoUrl',
        'addressProofUrl'
      ];

      if (sheet != null) {
        final firstRow = await sheet.values.row(1);
        // If the first row doesn't look like our headers, insert them
        if (firstRow.isEmpty ||
            !firstRow.contains('billNumber') ||
            !firstRow.contains('customerId')) {
          print(
              'SheetsApi: Bills header missing or invalid. Inserting/Updating...');
          await sheet.values.insertRow(1, billHeaders);
        } else {
          bool headersModified = false;
          final updatedHeaders = List<String>.from(firstRow.map((e) => e.toString()));
          
          if (!updatedHeaders.contains('branch')) {
             updatedHeaders.add('branch');
             headersModified = true;
          }
          if (headersModified) {
             print('SheetsApi: Appending missing columns to Bills sheet...');
             await sheet.values.insertRow(1, updatedHeaders);
          }
        }
      }

      var cSheet = ss.worksheetByTitle('Customers');
      cSheet ??= await ss.addWorksheet('Customers');
      _customersSheet = cSheet;

      if (cSheet != null) {
        final firstRow = await cSheet.values.row(1);
        if (firstRow.isEmpty || !firstRow.contains('phone')) {
          print(
              'SheetsApi: Customers header missing or invalid. Inserting/Updating...');
          await cSheet.values.insertRow(1, customerHeaders);
        } else {
          // Check for new columns in legacy sheets
          bool headersModified = false;
          final updatedHeaders = List<String>.from(firstRow.map((e) => e.toString()));
          
          if (!updatedHeaders.contains('profilePhotoUrl')) {
             updatedHeaders.add('profilePhotoUrl');
             headersModified = true;
          }
          if (!updatedHeaders.contains('addressProofUrl')) {
             updatedHeaders.add('addressProofUrl');
             headersModified = true;
          }
          if (headersModified) {
             print('SheetsApi: Appending missing columns to Customers sheet...');
             await cSheet.values.insertRow(1, updatedHeaders);
          }
        }
      }

      var sSheet = ss.worksheetByTitle('Suggestions');
      sSheet ??= await ss.addWorksheet('Suggestions');
      _suggestionsSheet = sSheet;
      if (sSheet != null) {
        final firstRow = await sSheet.values.row(1);
        if (firstRow.isEmpty) {
          await sSheet.values.insertRow(1, ['materialName']);
        }
      }

      print('SheetsApi: Successfully initialized');
    } catch (e) {
      print('SheetsApi Init Error: $e');
    }
  }

  static Future<List<Bill>> getAllBills() async {
    if (_billsSheet == null) {
      print('SheetsApi: Bills sheet is null');
      return [];
    }
    try {
      final rawValues = await _billsSheet!.values.allRows();
      print('SheetsApi: Raw row count: ${rawValues.length}');
      if (rawValues.isNotEmpty) print('SheetsApi: Raw Row 1: ${rawValues[0]}');
      if (rawValues.length > 1) print('SheetsApi: Raw Row 2: ${rawValues[1]}');

      final rows = await _billsSheet!.values.map.allRows();
      if (rows == null) {
        print('SheetsApi: No bills rows found');
        return [];
      }
      print(
          'SheetsApi: Fetched ${rows.length} bill rows from ${_billsSheet!.title}');
      if (rows.isNotEmpty)
        print('SheetsApi: First row keys: ${rows.first.keys}');

      return rows
          .asMap()
          .entries
          .map((entry) {
            final idx = entry.key;
            final r = entry.value;
            try {
              final rawId = r['id'];
              final billNum = r['billNumber'] ?? 'Manual-${idx + 1}';

              // If ID is missing, generate a stable one
              final id = (rawId == null || rawId.isEmpty)
                  ? 'legacy-$billNum'.replaceAll(' ', '-')
                  : rawId;

              print('SheetsApi: Parsing row $idx (ID: $id, Num: $billNum)');

              // Lenient materials parsing
              List<RentalMaterial> mats = [];
              final rawMats = r['materials'] ?? '';
              if (rawMats.startsWith('[') && rawMats.endsWith(']')) {
                try {
                  mats = (jsonDecode(rawMats) as List)
                      .map((m) => RentalMaterial.fromJson(m))
                      .toList();
                } catch (_) {
                  mats = [
                    RentalMaterial(
                        name: rawMats, days: 30, dueDate: DateTime.now())
                  ];
                }
              } else if (rawMats.isNotEmpty) {
                // Fallback for manual text entry
                mats = [
                  RentalMaterial(
                      name: rawMats, days: 30, dueDate: DateTime.now())
                ];
              }

              return Bill(
                id: id,
                billNumber: billNum,
                type: BillType.values.firstWhere((e) => e.name == r['type'],
                    orElse: () => BillType.bill),
                customerName: r['customerName'] ?? 'Manual Entry',
                customerId: r['customerId'] ?? '',
                site: r['site'] ?? '',
                billDate:
                    DateTime.tryParse(r['billDate'] ?? '') ?? DateTime.now(),
                branch: r['branch'] ?? '',
                materials: mats,
              );
            } catch (e) {
              print('SheetsApi: Error parsing bill row at index $idx: $e');
              return null;
            }
          })
          .whereType<Bill>()
          .toList();
    } catch (e) {
      print('SheetsApi: Fetch Bills Error: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getAllCustomersRaw() async {
    if (_customersSheet == null) {
      print('SheetsApi: Customers sheet is null');
      return [];
    }
    try {
      final rawValues = await _customersSheet!.values.allRows();
      if (rawValues.length > 1)
        print('SheetsApi: Customer Raw Row 2: ${rawValues[1]}');

      final rows = await _customersSheet!.values.map.allRows();
      if (rows == null) {
        print('SheetsApi: No customer rows found');
        return [];
      }
      print('SheetsApi: Fetched ${rows.length} customer rows');

      return rows
          .asMap()
          .entries
          .map((entry) {
            final idx = entry.key;
            final r = entry.value;
            if (r['name'] == null || r['name']!.isEmpty) return null;

            final rawId = r['id'];
            final id = (rawId == null || rawId.isEmpty)
                ? 'legacy-cust-${idx + 1}'
                : rawId;

            // Copy the map to modify ID if needed
            final data = Map<String, dynamic>.from(r);
            data['id'] = id;
            return data;
          })
          .whereType<Map<String, dynamic>>()
          .toList();
    } catch (e) {
      print('SheetsApi: Fetch Customers Error: $e');
      return [];
    }
  }

  static Future<bool> insertOrUpdateBill(Bill bill) async {
    if (_billsSheet == null) return false;
    try {
      print('SheetsApi: Saving bill ${bill.billNumber} (${bill.id})');
      final materialsJson =
          jsonEncode(bill.materials.map((m) => m.toJson()).toList());
      final mapData = {
        'id': bill.id,
        'billNumber': bill.billNumber,
        'type': bill.type.name,
        'customerName': bill.customerName,
        'customerId': bill.customerId,
        'site': bill.site,
        'billDate': bill.billDate.toIso8601String(),
        'branch': bill.branch,
        'materials': materialsJson,
      };

      final rows = await _billsSheet!.values.allRows();
      int index = rows.indexWhere((r) => r.isNotEmpty && r[0] == bill.id);

      // If we can't find by ID, try finding by matching the billNumber (e.g. legacy rows)
      if (index == -1) {
        index = rows.indexWhere((r) => r.length > 1 && r[1] == bill.billNumber);
        if (index != -1) {
          // Found a matching bill. Update its empty ID cell to the new ID so that future keys match.
          await _billsSheet!.values
              .insertValue(bill.id, column: 1, row: index + 1);
        }
      }

      final success = await _billsSheet!.values.map
          .insertRowByKey(bill.id, mapData, appendMissing: true);
      print('SheetsApi: Save bill ${bill.id} success: $success');
      return success;
    } catch (e) {
      print('SheetsApi: Insert Bill Error: $e');
      return false;
    }
  }

  static Future<bool> deleteBillRow(String id) async {
    if (_billsSheet == null) return false;
    try {
      print('SheetsApi: Deleting bill $id');
      final rows = await _billsSheet!.values.allRows();
      int index = rows.indexWhere((r) => r.isNotEmpty && r[0] == id);

      // Fallback for legacy bills without ID
      if (index == -1 && id.startsWith('legacy-')) {
        final billNum = id.replaceFirst('legacy-', '').replaceAll('-', ' ');
        index = rows.indexWhere((r) => r.length > 1 && r[1] == billNum);
      }

      if (index != -1) {
        // gsheets is 1-based, so row 1 is headers (index 0).
        // index 1 is row 2. So we delete index + 1
        final success = await _billsSheet!.deleteRow(index + 1);
        print('SheetsApi: Delete bill $id success: $success');
        return success;
      }
      return false;
    } catch (e) {
      print('SheetsApi: Delete Bill Error: $e');
      return false;
    }
  }

  static Future<List<String>> getSuggestions() async {
    if (_suggestionsSheet == null) return [];
    try {
      final rows = await _suggestionsSheet!.values.allRows(fromRow: 2);
      return rows
          .where((r) => r.isNotEmpty)
          .map((r) => r.first.toString())
          .toList();
    } catch (e) {
      print('SheetsApi: Get Suggestions Error: $e');
      return [];
    }
  }

  static Future<void> saveSuggestion(String name) async {
    if (_suggestionsSheet == null) return;
    try {
      // Check if already exists to avoid duplicates
      final all = await getSuggestions();
      if (!all.contains(name)) {
        await _suggestionsSheet!.values.appendRow([name]);
      }
    } catch (e) {
      print('SheetsApi: Save Suggestion Error: $e');
    }
  }

  static Future<bool> insertOrUpdateCustomer(Customer customer) async {
    if (_customersSheet == null) return false;
    try {
      print('SheetsApi: Saving customer ${customer.name} (${customer.id})');

      final rows = await _customersSheet!.values.allRows();
      int index = rows.indexWhere((r) => r.isNotEmpty && r[0] == customer.id);

      // Legacy fallback: find by matching phone + name
      if (index == -1) {
        index = rows.indexWhere((r) =>
            r.length > 2 && r[1] == customer.name && r[2] == customer.phone);
        if (index != -1) {
          await _customersSheet!.values
              .insertValue(customer.id, column: 1, row: index + 1);
        }
      }

      final success = await _customersSheet!.values.map
          .insertRowByKey(customer.id, customer.toJson(), appendMissing: true);
      print('SheetsApi: Save customer ${customer.id} success: $success');
      return success;
    } catch (e) {
      print('SheetsApi: Insert Customer Error: $e');
      return false;
    }
  }

  static Future<bool> deleteCustomerRow(String id) async {
    if (_customersSheet == null) return false;
    try {
      print('SheetsApi: Deleting customer $id');
      final rows = await _customersSheet!.values.allRows();
      int index = rows.indexWhere((r) => r.isNotEmpty && r[0] == id);

      // Legacy fallback: id = legacy-cust-1 -> maps to data row 0 = total row index 1
      if (index == -1 && id.startsWith('legacy-cust-')) {
        final idNumStr = id.replaceFirst('legacy-cust-', '');
        int? rowOffset = int.tryParse(idNumStr);
        if (rowOffset != null && rowOffset < rows.length) {
          index = rowOffset;
        }
      }

      if (index != -1) {
        final success = await _customersSheet!.deleteRow(index + 1);
        print('SheetsApi: Delete customer $id success: $success');
        return success;
      }
      return false;
    } catch (e) {
      print('SheetsApi: Delete Customer Error: $e');
      return false;
    }
  }
}
