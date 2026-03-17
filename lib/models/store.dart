import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'bill.dart';
import 'customer.dart';
import '../services/firestore_db.dart';
import '../services/storage.dart';
import 'dart:typed_data';

class AppStore extends ChangeNotifier {
  List<Bill> _bills = [];
  List<Customer> _customers = [];
  List<String> _suggestions = [];
  bool _loaded = false;
  bool _isReady = false;
  String _selectedBranch = '';

  // Branch-filtered view of all bills
  List<Bill> get bills => _selectedBranch.isEmpty
      ? _bills
      : _bills.where((b) => b.branch == _selectedBranch).toList();
  List<Customer> get customers => _customers;
  List<String> get suggestions => _suggestions;
  bool get loaded => _loaded;
  bool get isReady => _isReady;
  String get selectedBranch => _selectedBranch;

  /// Returns bill count for a branch regardless of current branch filter.
  int billCountForBranch(String branch) =>
      _bills.where((b) => b.branch == branch).length;

  Future<void> setSelectedBranch(String branch) async {
    _selectedBranch = branch;
    notifyListeners();
    await LocalStorage.setPreference('selected_branch', branch);
  }

  // Stats — all based on branch-filtered `bills`
  int get totalBills => bills.length;
  int get totalCustomers => _customers.length;
  int get pendingCount => bills
      .where((b) =>
          !b.isBilled && b.status != BillStatus.allReturned && b.status != BillStatus.billedDC)
      .length;
  int get todayCount {
    final today = DateTime.now();
    return bills
        .where((b) =>
            b.billDate.year == today.year &&
            b.billDate.month == today.month &&
            b.billDate.day == today.day)
        .length;
  }

  List<Bill> get recentBills => bills.take(5).toList();

  /// Total pending material quantity across all active bills in the current branch.
  int get pendingMaterialsCount {
    int count = 0;
    for (final b in bills) {
      if (b.status == BillStatus.allReturned) continue;
      for (final m in b.materials) {
        if (m.isPending) count += m.quantity.ceil();
      }
      for (final cb in b.columnBoxes) {
        if (!cb.isReturned) count += cb.totalQty;
      }
      for (final rb in b.roundBoxes) {
        if (!rb.isReturned) count += rb.totalQty;
      }
    }
    return count;
  }

  /// Number of distinct customers who have pending materials.
  int get customersWithPendingCount => bills
      .where((b) =>
          b.customerId.isNotEmpty && b.status != BillStatus.allReturned)
      .map((b) => b.customerId)
      .toSet()
      .length;

  List<Bill> filtered(String? filter, String search) {
    var list = List<Bill>.from(bills); // branch-filtered

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
            return !b.isBilled && b.status != BillStatus.allReturned && b.status != BillStatus.billedDC;
          case 'partial':
            return b.status == BillStatus.partial;
          case 'returned':
            return b.status == BillStatus.allReturned;
          case 'dc':
            return b.type == BillType.dc && !b.isBilled;
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

    // Initialize Firestore offline persistence FIRST — must be done before
    // any Firestore operation so writes are persisted locally even if the
    // network write doesn't complete before the app closes.
    await FirestoreDb.init();

    // Load saved branch preference
    _selectedBranch = LocalStorage.getPreference('selected_branch') ?? '';

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

      final bList = await FirestoreDb.getAllBills();
      final cListRaw = await FirestoreDb.getAllCustomersRaw();
      final sList = await FirestoreDb.getSuggestions();

      print('AppStore: 🔄 Sync Complete: ${bList.length} bills, ${cListRaw.length} customers');

      // Sort latest first
      bList.sort((a, b) => b.billDate.compareTo(a.billDate));
      _bills = bList;

      // Merge remote customers with any locally-written ones that haven't
      // synced to the server yet (fire-and-forget writes still in-flight).
      final remoteCustomers = cListRaw.map((r) => Customer.fromJson(r)).toList();
      final remoteIds = remoteCustomers.map((c) => c.id).toSet();
      final pendingLocal = _customers.where((c) => !remoteIds.contains(c.id)).toList();
      _customers = [...pendingLocal, ...remoteCustomers];
      
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

  Future<void> markMaterialReturned(String billId, String materialId, DateTime returnDate) async {
    final bill = _bills.firstWhere((b) => b.id == billId);
    final idx = bill.materials.indexWhere((m) => m.id == materialId);
    if (idx != -1 && bill.materials[idx].isPending) {
      bill.materials[idx] = bill.materials[idx].copyWith(
        status: MaterialStatus.returned,
        returnDate: returnDate,
      );
      notifyListeners();
      await FirestoreDb.insertOrUpdateBill(bill);
    }
  }

  Future<void> markColumnBoxReturned(String billId, String sizeKey, DateTime returnDate) async {
    final bill = _bills.firstWhere((b) => b.id == billId);
    final idx = bill.columnBoxes.indexWhere((b) => b.sizeKey == sizeKey);
    if (idx != -1 && !bill.columnBoxes[idx].isReturned) {
      bill.columnBoxes[idx] = bill.columnBoxes[idx].copyWith(
        isReturned: true,
        returnDate: returnDate,
      );
      notifyListeners();
      await FirestoreDb.insertOrUpdateBill(bill);
    }
  }

  Future<void> markRoundBoxReturned(String billId, String sizeKey, DateTime returnDate) async {
    final bill = _bills.firstWhere((b) => b.id == billId);
    final idx = bill.roundBoxes.indexWhere((b) => b.sizeKey == sizeKey);
    if (idx != -1 && !bill.roundBoxes[idx].isReturned) {
      bill.roundBoxes[idx] = bill.roundBoxes[idx].copyWith(
        isReturned: true,
        returnDate: returnDate,
      );
      notifyListeners();
      await FirestoreDb.insertOrUpdateBill(bill);
    }
  }

  Future<void> markPalagaiReturned(String billId, int index, DateTime returnDate) async {
    final bill = _bills.firstWhere((b) => b.id == billId);
    if (index >= 0 && index < bill.palagai.length && !bill.palagai[index].isReturned) {
      bill.palagai[index] = bill.palagai[index].copyWith(
        isReturned: true,
        returnDate: returnDate,
      );
      notifyListeners();
      await FirestoreDb.insertOrUpdateBill(bill);
    }
  }

  Future<void> markMuttuReturned(String billId, int index, DateTime returnDate) async {
    final bill = _bills.firstWhere((b) => b.id == billId);
    if (index >= 0 && index < bill.muttu.length && !bill.muttu[index].isReturned) {
      bill.muttu[index] = bill.muttu[index].copyWith(
        isReturned: true,
        returnDate: returnDate,
      );
      notifyListeners();
      await FirestoreDb.insertOrUpdateBill(bill);
    }
  }

  Future<void> markSideSheetReturned(String billId, int index, DateTime returnDate) async {
    final bill = _bills.firstWhere((b) => b.id == billId);
    if (index >= 0 && index < bill.sideSheets.length && !bill.sideSheets[index].isReturned) {
      bill.sideSheets[index] = bill.sideSheets[index].copyWith(
        isReturned: true,
        returnDate: returnDate,
      );
      notifyListeners();
      await FirestoreDb.insertOrUpdateBill(bill);
    }
  }

  Future<void> markRoofMaterialReturned(String billId, int index, DateTime returnDate) async {
    final bill = _bills.firstWhere((b) => b.id == billId);
    if (index >= 0 && index < bill.roofItems.length && !bill.roofItems[index].isReturned) {
      bill.roofItems[index] = bill.roofItems[index].copyWith(
        isReturned: true,
        returnDate: returnDate,
      );
      notifyListeners();
      await FirestoreDb.insertOrUpdateBill(bill);
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
      // Defensive fallback: keep existing branch if an edit payload omits it.
      if (bill.branch.trim().isEmpty) {
        bill.branch = _bills[idx].branch;
      }
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
    // Write to local cache immediately — screen returns fast, restart is safe.
    // Firestore write runs in background; offline persistence guarantees sync.
    await _saveCustomersCache();
    FirestoreDb.insertOrUpdateCustomer(customer);
  }

  Future<void> updateCustomer(Customer customer) async {
    final idx = _customers.indexWhere((c) => c.id == customer.id);
    if (idx != -1) {
      _customers[idx] = customer;
      notifyListeners();
      await _saveCustomersCache();
      FirestoreDb.insertOrUpdateCustomer(customer);
    }
  }

  Future<void> _saveCustomersCache() async {
    await LocalStorage.saveCache(
        'customers', jsonEncode(_customers.map((e) => e.toJson()).toList()));
  }

  /// Encode bytes as base64 data URL and save directly to Firestore customer record.
  /// This avoids all Firebase Storage complexity — Firestore already works perfectly.
  Future<void> uploadAndSetCustomerPhoto(
    String customerId,
    String fileName,
    Uint8List bytes, {
    bool isAddressProof = false,
  }) async {
    try {
      // Encode bytes as base64 data URL (data:image/jpeg;base64,...)
      final base64Str = base64Encode(bytes);
      final dataUrl = 'data:image/jpeg;base64,$base64Str';

      final cIdx = _customers.indexWhere((c) => c.id == customerId);
      if (cIdx != -1) {
        final c = _customers[cIdx];
        final updated = isAddressProof
            ? c.copyWith(addressProofUrls: [...c.addressProofUrls, dataUrl])
            : c.copyWith(profilePhotoUrl: dataUrl);

        _customers[cIdx] = updated;
        notifyListeners();

        await FirestoreDb.insertOrUpdateCustomer(updated);
        print('AppStore: ✅ Photo saved as base64 in Firestore for $customerId');
      }
    } catch (e) {
      print('AppStore: ❌ Upload failed: $e');
      rethrow;
    }
  }

  Future<void> deleteCustomer(String id) async {
    final cIdx = _customers.indexWhere((c) => c.id == id);
    if (cIdx == -1) return;

    _customers.removeAt(cIdx);
    notifyListeners();
    await FirestoreDb.deleteCustomerRow(id);
    // Note: base64 image data is stored IN the Firestore document,
    // so it is automatically deleted when the customer document is deleted.
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

  List<Bill> getUnbilledDCs(String customerId) {
    return bills  // branch-filtered
        .where((b) =>
            b.customerId == customerId &&
            b.type == BillType.dc &&
            !b.isBilled)
        .toList();
  }

  Future<void> consolidateDCsToBill(Bill bill, List<String> dcIds) async {
    // 1. Add the main Bill
    await addBill(bill);

    // 2. Mark source DCs as billed
    for (final id in dcIds) {
      final idx = _bills.indexWhere((b) => b.id == id);
      if (idx != -1) {
        _bills[idx].isBilled = true;
        _bills[idx].parentId = bill.id;
        await FirestoreDb.insertOrUpdateBill(_bills[idx]);
      }
    }
    notifyListeners();
  }
}
