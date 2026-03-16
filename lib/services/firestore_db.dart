import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bill.dart';
import '../models/customer.dart';

/// Firebase Firestore replacement for the old Google Sheets database.
///
/// Collections:
///   bills/        — one doc per Bill, keyed by bill.id
///   customers/    — one doc per Customer, keyed by customer.id
///   meta/suggestions — single doc with field `names: [...]`
class FirestoreDb {
  static final _db = FirebaseFirestore.instance;

  static CollectionReference get _bills => _db.collection('bills');
  static CollectionReference get _customers => _db.collection('customers');
  static DocumentReference get _suggestionsDoc =>
      _db.collection('meta').doc('suggestions');

  /// No-op — Firestore initialises automatically via Firebase.initializeApp().
  static Future<void> init() async {
    // Enable offline persistence (works on both Android and Windows)
    _db.settings = const Settings(persistenceEnabled: true);
  }

  // ─── Bills ────────────────────────────────────────────────────────────────

  static Future<List<Bill>> getAllBills() async {
    try {
      final snap = await _bills.get();
      final results = <Bill>[];
      for (final doc in snap.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          
          // materials stored as JSON string for simplicity
          final rawMats = data['materials'];
          List<RentalMaterial> mats = [];
          if (rawMats is String && rawMats.startsWith('[')) {
            mats = (jsonDecode(rawMats) as List)
                .map((m) => RentalMaterial.fromJson(m))
                .toList();
          }

          // columnBoxes also stored as JSON string
          final rawCB = data['columnBoxes'];
          List<ColumnSizeBlock> cBoxes = [];
          if (rawCB is String && rawCB.startsWith('[')) {
            cBoxes = (jsonDecode(rawCB) as List)
                .map((b) => ColumnSizeBlock.fromJson(Map<String, dynamic>.from(b)))
                .toList();
          }

          // roundBoxes stored as JSON string
          final rawRB = data['roundBoxes'];
          List<ColumnSizeBlock> rBoxes = [];
          if (rawRB is String && rawRB.startsWith('[')) {
            rBoxes = (jsonDecode(rawRB) as List)
                .map((b) => ColumnSizeBlock.fromJson(Map<String, dynamic>.from(b)))
                .toList();
          }

          results.add(Bill(
            id: doc.id,
            billNumber: data['billNumber'] ?? '',
            type: BillType.values.firstWhere(
              (e) => e.name == data['type'],
              orElse: () => BillType.bill,
            ),
            customerName: data['customerName'] ?? '',
            customerId: data['customerId'] ?? '',
            site: data['site'] ?? '',
            branch: data['branch'] ?? 'Kovilambakkam',
            billDate: (data['billDate'] is Timestamp)
                ? (data['billDate'] as Timestamp).toDate()
                : DateTime.tryParse(data['billDate'] ?? '') ?? DateTime.now(),
            materials: mats,
            columnBoxes: cBoxes,
            roundBoxes: rBoxes,
            vehicleChargeUp: (data['vehicleChargeUp'] as num?)?.toDouble() ?? 0.0,
            vehicleChargeDown: (data['vehicleChargeDown'] as num?)?.toDouble() ?? 0.0,
            labourChargeUp: (data['labourChargeUp'] as num?)?.toDouble() ?? 0.0,
            labourChargeDown: (data['labourChargeDown'] as num?)?.toDouble() ?? 0.0,
            gstEnabled: data['gstEnabled'] as bool? ?? false,
            advancePaid: (data['advancePaid'] as num?)?.toDouble() ?? 0.0,
            isBilled: data['isBilled'] as bool? ?? false,
            parentId: data['parentId'] as String?,
            linkedDcIds: List<String>.from(data['linkedDcIds'] ?? []),
          ));
        } catch (e) {
          print('FirestoreDb: Error parsing bill ${doc.id}: $e');
        }
      }
      return results;
    } catch (e) {
      print('FirestoreDb: getAllBills error: $e');
      return [];
    }
  }

  static Future<bool> insertOrUpdateBill(Bill bill) async {
    try {
      final materialsJson =
          jsonEncode(bill.materials.map((m) => m.toJson()).toList());
      final columnBoxesJson =
          jsonEncode(bill.columnBoxes.map((b) => b.toJson()).toList());
      final roundBoxesJson =
          jsonEncode(bill.roundBoxes.map((b) => b.toJson()).toList());

      await _bills.doc(bill.id).set({
        'billNumber': bill.billNumber,
        'type': bill.type.name,
        'customerName': bill.customerName,
        'customerId': bill.customerId,
        'site': bill.site,
        'branch': bill.branch,
        'billDate': Timestamp.fromDate(bill.billDate),
        'materials': materialsJson,
        'columnBoxes': columnBoxesJson,
        'roundBoxes': roundBoxesJson,
        'vehicleChargeUp': bill.vehicleChargeUp,
        'vehicleChargeDown': bill.vehicleChargeDown,
        'labourChargeUp': bill.labourChargeUp,
        'labourChargeDown': bill.labourChargeDown,
        'gstEnabled': bill.gstEnabled,
        'advancePaid': bill.advancePaid,
        'isBilled': bill.isBilled,
        'parentId': bill.parentId,
        'linkedDcIds': bill.linkedDcIds,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      print('FirestoreDb: ✅ Bill saved: ${bill.id}');
      return true;
    } catch (e) {
      print('FirestoreDb: insertOrUpdateBill error: $e');
      return false;
    }
  }

  static Future<bool> deleteBillRow(String id) async {
    try {
      await _bills.doc(id).delete();
      print('FirestoreDb: ✅ Bill deleted: $id');
      return true;
    } catch (e) {
      print('FirestoreDb: deleteBillRow error: $e');
      return false;
    }
  }

  // ─── Customers ────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getAllCustomersRaw() async {
    try {
      final snap = await _customers.get();
      return snap.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map);
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('FirestoreDb: getAllCustomersRaw error: $e');
      return [];
    }
  }

  static Future<bool> insertOrUpdateCustomer(Customer customer) async {
    try {
      final data = customer.toJson();
      data['updatedAt'] = FieldValue.serverTimestamp();
      await _customers.doc(customer.id).set(data, SetOptions(merge: true));
      print('FirestoreDb: ✅ Customer saved: ${customer.id}');
      return true;
    } catch (e) {
      print('FirestoreDb: insertOrUpdateCustomer error: $e');
      return false;
    }
  }

  static Future<bool> deleteCustomerRow(String id) async {
    try {
      await _customers.doc(id).delete();
      print('FirestoreDb: ✅ Customer deleted: $id');
      return true;
    } catch (e) {
      print('FirestoreDb: deleteCustomerRow error: $e');
      return false;
    }
  }

  // ─── Suggestions ──────────────────────────────────────────────────────────

  static Future<List<String>> getSuggestions() async {
    try {
      final doc = await _suggestionsDoc.get();
      if (!doc.exists) return [];
      final data = doc.data() as Map<String, dynamic>?;
      final names = data?['names'];
      if (names is List) return List<String>.from(names);
      return [];
    } catch (e) {
      print('FirestoreDb: getSuggestions error: $e');
      return [];
    }
  }

  static Future<void> saveSuggestion(String name) async {
    try {
      await _suggestionsDoc.set({
        'names': FieldValue.arrayUnion([name]),
      }, SetOptions(merge: true));
    } catch (e) {
      print('FirestoreDb: saveSuggestion error: $e');
    }
  }
}
