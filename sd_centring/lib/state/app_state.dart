import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/dates.dart';
import '../data/file_store.dart';
import '../data/repository.dart';
import '../domain/expiry.dart';
import '../domain/reminders.dart';
import '../models/customer.dart';
import '../models/rental.dart';
import '../services/reminder_scheduler.dart';
import 'drafts.dart';
import 'settings.dart';

/// Live view of all customers and deliveries, plus the actions screens use.
///
/// Data streams straight from the repository (Firestore keeps its own
/// offline cache), so there is no second hand-rolled cache to drift out of
/// sync. Reminders are re-planned whenever data or settings change.
class AppState extends ChangeNotifier {
  AppState({
    required this.repo,
    required this.settings,
    required this.scheduler,
    this.accountEmail,
    this.signOut,
    FileStore? files,
    DraftStore? drafts,
    DateTime Function()? clock,
  }) : files = files ?? MemoryFileStore(),
       drafts = drafts ?? DraftStore.inMemory(),
       _clock = clock ?? DateTime.now {
    _subs.add(
      repo.watchCustomers().listen((list) {
        list.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        _customers = list;
        _customersById = {for (final c in list) c.id: c};
        _customersLoaded = true;
        _changed();
      }, onError: _onStreamError),
    );
    _subs.add(
      repo.watchRentals().listen((list) {
        list.sort(compareByUrgency);
        _rentals = list;
        _rentalsLoaded = true;
        _changed();
      }, onError: _onStreamError),
    );
    _subs.add(
      repo.writeErrors.listen((msg) {
        _lastError = msg;
        notifyListeners();
      }),
    );
    settings.addListener(_changed);
    repo.pendingCustomerIds.addListener(_onPendingChanged);
  }

  void _onPendingChanged() {
    if (!_disposed) notifyListeners();
  }

  /// True while this customer's latest change has not reached the cloud.
  bool isPending(String customerId) =>
      repo.pendingCustomerIds.value.contains(customerId);

  final Repository repo;
  final ReminderSettings settings;
  final ReminderScheduler scheduler;

  /// Customer photos and documents.
  final FileStore files;

  /// Half-typed forms kept on this device.
  final DraftStore drafts;

  /// Signed-in account, shown in Settings. Null in demo mode.
  final String? accountEmail;

  /// Signs out of the current session. Null in demo mode.
  final Future<void> Function()? signOut;

  final DateTime Function() _clock;
  final _subs = <StreamSubscription<Object?>>[];
  Timer? _rescheduleTimer;
  bool _disposed = false;

  List<Customer> _customers = const [];
  Map<String, Customer> _customersById = const {};
  List<Rental> _rentals = const [];
  bool _customersLoaded = false;
  bool _rentalsLoaded = false;
  String? _lastError;

  bool get loaded => _customersLoaded && _rentalsLoaded;
  bool get isDemo => repo.isDemo;

  /// Set when the database refuses to load (e.g. rules deny access). Stays
  /// visible on screen instead of silently showing old data.
  String? get loadError => _loadError;
  String? _loadError;
  List<Customer> get customers => _customers;

  /// All deliveries, most urgent first.
  List<Rental> get rentals => _rentals;

  DateTime get today => dayOf(_clock());

  /// One-shot error message for the UI to show; cleared once read.
  String? takeError() {
    final e = _lastError;
    _lastError = null;
    return e;
  }

  Customer? customerById(String id) => _customersById[id];

  Rental? rentalById(String id) {
    for (final r in _rentals) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// Prefers the live customer record so renames show everywhere.
  String customerNameOf(Rental r) =>
      _customersById[r.customerId]?.name ?? r.customerName;

  ExpiryInfo expiry(Rental r) =>
      expiryOf(r, today: today, soonDays: settings.leadDays);

  List<Rental> rentalsFor(String customerId) =>
      _rentals.where((r) => r.customerId == customerId).toList();

  List<Rental> withStatus(ExpiryStatus status) =>
      _rentals.where((r) => expiry(r).status == status).toList();

  // ── Actions ────────────────────────────────────────────────────────────

  Future<void> saveCustomer(Customer c) => repo.saveCustomer(c);

  /// Other customers whose main or alternate number matches any of
  /// [phones] (compared on the last 10 digits).
  List<Customer> customersWithPhone(
    Iterable<String> phones, {
    String? exceptId,
  }) {
    final keys = {
      for (final p in phones)
        if (phoneKey(p).length >= 10) phoneKey(p),
    };
    if (keys.isEmpty) return const [];
    return _customers
        .where(
          (c) =>
              c.id != exceptId &&
              (keys.contains(phoneKey(c.phone)) ||
                  (c.altPhone.isNotEmpty &&
                      keys.contains(phoneKey(c.altPhone)))),
        )
        .toList();
  }

  /// Refuses to delete a customer who still has deliveries on record.
  Future<bool> deleteCustomer(String id) async {
    if (_rentals.any((r) => r.customerId == id)) return false;
    final c = _customersById[id];
    await repo.deleteCustomer(id);
    // Remove their photo and documents from storage too.
    if (c != null) {
      if (c.photoUrl.isNotEmpty) unawaited(files.delete(c.photoUrl));
      for (final d in c.documents) {
        unawaited(files.delete(d.url));
      }
    }
    return true;
  }

  Future<void> saveRental(Rental r) =>
      repo.saveRental(r.copyWith(updatedAt: _clock()));

  Future<void> deleteRental(String id) => repo.deleteRental(id);

  Future<void> addReturns(Rental r, List<ReturnEntry> entries) =>
      saveRental(r.copyWith(returns: [...r.returns, ...entries]));

  Future<void> undoReturn(Rental r, String returnId) => saveRental(
    r.copyWith(returns: r.returns.where((x) => x.id != returnId).toList()),
  );

  Future<void> changeExpiry(Rental r, DateTime newDate) {
    final to = dayOf(newDate);
    if (to == r.expiresOn) return Future.value();
    return saveRental(
      r.copyWith(
        expiresOn: to,
        expiryHistory: [
          ...r.expiryHistory,
          ExpiryChange(from: r.expiresOn, to: to, changedAt: _clock()),
        ],
      ),
    );
  }

  Future<void> markMessaged(Rental r) =>
      saveRental(r.copyWith(lastMessagedAt: _clock()));

  // ── Reminders ──────────────────────────────────────────────────────────

  List<PlannedReminder> currentPlan() => planReminders(
    _rentals,
    now: _clock(),
    leadDays: settings.leadDays,
    hour: settings.hour,
    minute: settings.minute,
    customerNameOf: customerNameOf,
  );

  /// Call when the app returns to the foreground: "today" may have changed.
  void refresh() => _changed();

  void _changed() {
    if (_disposed) return;
    notifyListeners();
    if (!loaded) return;
    // Debounce: a burst of snapshot updates schedules only once.
    _rescheduleTimer?.cancel();
    _rescheduleTimer = Timer(const Duration(milliseconds: 600), () {
      if (!_disposed) scheduler.apply(currentPlan());
    });
  }

  void _onStreamError(Object e) {
    debugPrint('AppState: stream error: $e');
    _customersLoaded = true;
    _rentalsLoaded = true;
    _loadError = e.toString().contains('permission-denied')
        ? 'The database refused access, so changes are NOT being saved. '
              'Ask the owner to add your account to the staff list, '
              'then sign out and in again.'
        : 'Could not load data from the cloud. Changes may not be saved.';
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _rescheduleTimer?.cancel();
    settings.removeListener(_changed);
    repo.pendingCustomerIds.removeListener(_onPendingChanged);
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}
