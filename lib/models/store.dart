import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'bill.dart';
import 'customer.dart';
import '../services/firestore_db.dart';
import '../services/drive_api.dart';
import '../services/firebase_storage_service.dart';
import '../services/storage.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';

class AppStore extends ChangeNotifier {
  List<Bill> _bills = [];
  List<Customer> _customers = [];
  List<String> _suggestions = [];
  bool _loaded = false;
  bool _isReady = false;

  List<Bill> get bills => _bills;
  List<Customer> get customers => _customers;
  List<String> get suggestions => _suggestions;
  bool get loaded => _loaded;
  bool get isReady => _isReady;

  // Stats
  int get totalBills => _bills.length;
  int get totalCustomers => _customers.length;
  int get pendingCount => _bills
      .where((b) =>
          b.status == BillStatus.allPending || b.status == BillStatus.partial || b.status == BillStatus.dc)
      .length;
  int get todayCount {
    final today = DateTime.now();
    return _bills
        .where((b) =>
            b.billDate.year == today.year &&
            b.billDate.month == today.month &&
            b.billDate.day == today.day)
        .length;
  }

  List<Bill> get recentBills => _bills.take(5).toList();

  List<Bill> filtered(String? filter, String search) {
    var list = List<Bill>.from(_bills);

    if (filter != null && filter != 'all') {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final nextWeek = today.add(const Duration(days: 7));

      list = list.where((b) {
        if (b.status == BillStatus.allReturned &&
            (filter == 'overdue' || filter == 'week')) {
          return false;
        }

        switch (filter) {
          case 'pending':
            return b.status == BillStatus.allPending || b.status == BillStatus.partial || b.status == BillStatus.dc;
          case 'partial':
            return b.status == BillStatus.partial;
          case 'returned':
            return b.status == BillStatus.allReturned;
          case 'dc':
            return b.status == BillStatus.dc;
          case 'overdue':
            return b.materials
                .any((m) => m.isPending && m.dueDate.isBefore(today));
          case 'week':
            return b.materials.any((m) =>
                m.isPending &&
                !m.dueDate.isBefore(today) &&
                m.dueDate.isBefore(nextWeek));
          default:
            return true;
        }
      }).toList();
    }

    if (search.isNotEmpty) {
      final q = search.toLowerCase();
      list = list.where((b) {
        // Find the customer to search phone
        final customer =
            _customers.where((c) => c.id == b.customerId).firstOrNull;
        return b.customerName.toLowerCase().contains(q) ||
            b.billNumber.toLowerCase().contains(q) ||
            b.site.toLowerCase().contains(q) ||
            (customer?.phone.contains(q) ?? false) ||
            (customer?.secondaryPhone.contains(q) ?? false);
      }).toList();
    }

    return list;
  }

  Future<void> initialize() async {
    print('AppStore: Initializing boot sequence...');
    
    // 1. Try loading from Cache first for instant-on behavior
    final cachedBills = LocalStorage.getCache('bills');
    final cachedCustomers = LocalStorage.getCache('customers');
    final cachedSuggestions = LocalStorage.getCache('suggestions');

    if (cachedBills != null && cachedCustomers != null) {
      print('AppStore: 📦 Loading from local cache...');
      try {
        _bills = (jsonDecode(cachedBills) as List)
            .map((e) => Bill.fromJson(e))
            .toList();
        _customers = (jsonDecode(cachedCustomers) as List)
            .map((e) => Customer.fromJson(e))
            .toList();
        if (cachedSuggestions != null) {
          _suggestions = List<String>.from(jsonDecode(cachedSuggestions));
        }
        _isReady = true;
        notifyListeners();
        print('AppStore: ✅ UI Ready via cache');
      } catch (e) {
        print('AppStore: ❌ Cache Parse Error: $e');
      }
    }

    // 2. Perform background sync from remote
    _syncFromRemote();
  }

  Future<void> _syncFromRemote() async {
    print('AppStore: 🔄 Starting background sync...');
    try {
      await dotenv.load(fileName: ".env");
      await FirestoreDb.init();
      await GoogleDriveApi.init();

      final bList = await FirestoreDb.getAllBills();
      final cListRaw = await FirestoreDb.getAllCustomersRaw();
      final sList = await FirestoreDb.getSuggestions();

      print('AppStore: 🔄 Sync Complete: ${bList.length} bills, ${cListRaw.length} customers');

      // Sort latest first
      bList.sort((a, b) => b.billDate.compareTo(a.billDate));
      _bills = bList;
      _customers = cListRaw.map((r) => Customer.fromJson(r)).toList();
      
      final fromBills = _bills.expand((b) => b.materials.map((m) => m.name)).toSet();
      _suggestions = {...sList, ...fromBills}.toList()..sort();

      // Update Cache
      await LocalStorage.saveCache('bills', jsonEncode(_bills.map((e) => e.toJson()).toList()));
      await LocalStorage.saveCache('customers', jsonEncode(_customers.map((e) => e.toJson()).toList()));
      await LocalStorage.saveCache('suggestions', jsonEncode(_suggestions));

      _isReady = true; // Guaranteed ready now if it wasn't before
      _loaded = true;
      notifyListeners();
    } catch (e) {
      print('AppStore: ❌ Remote Sync Error: $e');
      if (!_isReady) {
        // Network failed on first install – show empty dashboard rather than freeze
        _isReady = true;
        _loaded = true;
        notifyListeners();
      }
    }
  }

  Future<void> load() async {
    // Deprecated for initialize()
    return initialize();
  }

  /// Manually trigger a background sync and wait for it to complete.
  Future<void> sync() async {
    return _syncFromRemote();
  }

  Future<void> markMaterialReturned(String billId, String materialId) async {
    final bill = _bills.firstWhere((b) => b.id == billId);
    final idx = bill.materials.indexWhere((m) => m.id == materialId);
    if (idx != -1 && bill.materials[idx].isPending) {
      bill.materials[idx] =
          bill.materials[idx].copyWith(status: MaterialStatus.returned);
      notifyListeners(); // Update UI optimistically
      await FirestoreDb.insertOrUpdateBill(bill); // Sync to DB
    }
  }

  Future<void> addBill(Bill bill) async {
    _bills.insert(0, bill);
    for (final m in bill.materials) {
      await addSuggestion(m.name);
    }
    notifyListeners();
    await FirestoreDb.insertOrUpdateBill(bill);
  }

  Future<void> updateBill(Bill bill) async {
    final idx = _bills.indexWhere((b) => b.id == bill.id);
    if (idx != -1) {
      _bills[idx] = bill;
      for (final m in bill.materials) {
        await addSuggestion(m.name);
      }
      notifyListeners();
      await FirestoreDb.insertOrUpdateBill(bill);
    }
  }

  Future<void> deleteBill(String id) async {
    _bills.removeWhere((b) => b.id == id);
    notifyListeners();
    await FirestoreDb.deleteBillRow(id);
  }

  Future<void> addSuggestion(String name) async {
    final n = name.trim();
    if (n.isEmpty) return;
    if (!_suggestions.contains(n)) {
      _suggestions.add(n);
      _suggestions.sort();
      notifyListeners();
      await FirestoreDb.saveSuggestion(n);
    }
  }

  Future<void> addCustomer(Customer customer) async {
    _customers.insert(0, customer);
    notifyListeners();
    await FirestoreDb.insertOrUpdateCustomer(customer);
  }

  Future<void> updateCustomer(Customer customer) async {
    final idx = _customers.indexWhere((c) => c.id == customer.id);
    if (idx != -1) {
      _customers[idx] = customer;
      notifyListeners();
      await FirestoreDb.insertOrUpdateCustomer(customer);
    }
  }

  /// True background upload orchestration.
  /// Decoupled from UI unmounts. Guarantees db write for successful uploads.
  Future<void> uploadAndSetCustomerPhoto(
    String customerId,
    String fileName,
    Uint8List bytes, {
    bool isAddressProof = false,
  }) async {
    try {
      String path = isAddressProof
          ? 'customers/$customerId/address_proof_${DateTime.now().millisecondsSinceEpoch}.jpg'
          : 'customers/$customerId/profile_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final url = await FirebaseStorageService.uploadImage(
        path: path,
        bytes: bytes,
      );

      if (url != null) {
        final cIdx = _customers.indexWhere((c) => c.id == customerId);
        if (cIdx != -1) {
          final c = _customers[cIdx];
          final updated = isAddressProof
              ? c.copyWith(addressProofUrl: url)
              : c.copyWith(profilePhotoUrl: url);

          _customers[cIdx] = updated;
          notifyListeners(); // Optimistic UI update

          // Store the direct-access URL in the DB unconditionally
          await FirestoreDb.insertOrUpdateCustomer(updated);
          print('AppStore: ✅ Guaranteed Database Persistence for $fileName');
        }
      }
    } catch (e) {
      print('AppStore: ❌ Background upload orchestration failed: $e');
    }
  }

  Future<void> deleteCustomer(String id) async {
    final cIdx = _customers.indexWhere((c) => c.id == id);
    if (cIdx == -1) return;
    
    final customer = _customers[cIdx];
    final photoUrl = customer.profilePhotoUrl;
    final proofUrl = customer.addressProofUrl;

    _customers.removeAt(cIdx);
    notifyListeners();
    await FirestoreDb.deleteCustomerRow(id);

    // Fire off remote Firebase Storage file deletions in the background
    if (photoUrl.isNotEmpty) {
      print('AppStore: 🗑️ Scheduling profile photo deletion for $id...');
      FirebaseStorageService.deleteImage(photoUrl).then((success) => 
          print('AppStore: Profile photo deletion ${success ? "succeeded" : "failed"}')
      );
    }
    
    if (proofUrl.isNotEmpty) {
      print('AppStore: 🗑️ Scheduling address proof deletion for $id...');
      FirebaseStorageService.deleteImage(proofUrl).then((success) => 
          print('AppStore: Address proof deletion ${success ? "succeeded" : "failed"}')
      );
    }
  }

  String nextBillNumber(BillType type) {
    final prefix = type == BillType.dc ? 'DC' : 'Bill';
    int max = 6051;
    for (final b in _bills) {
      final n =
          int.tryParse(b.billNumber.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      if (n > max) max = n;
    }
    return '$prefix #${max + 1}';
  }
}
