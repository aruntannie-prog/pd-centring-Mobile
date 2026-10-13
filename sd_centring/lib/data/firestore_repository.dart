import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/customer.dart';
import '../models/rental.dart';
import 'repository.dart';

/// Firestore storage.
///
/// Collections:
///   customers/{id}
///   rentals/{id}   — items, returns and expiry history as native arrays
///
/// Security rules (firestore.rules) only allow signed-in users.
class FirestoreRepository implements Repository {
  FirestoreRepository(this._db) {
    // If the server never answers, switch from "connecting" to "offline".
    _connectTimer = Timer(const Duration(seconds: 9), _updateSync);
  }

  Timer? _connectTimer;
  bool _disposed = false;

  final FirebaseFirestore _db;
  final _errors = StreamController<String>.broadcast();

  CollectionReference<Map<String, dynamic>> get _customers =>
      _db.collection('customers');
  CollectionReference<Map<String, dynamic>> get _rentals =>
      _db.collection('rentals');

  @override
  bool get isDemo => false;

  final _sync = ValueNotifier<SyncState>(SyncState.connecting);
  bool _customersPending = false, _rentalsPending = false;
  bool _customersCached = true, _rentalsCached = true;
  bool _heardFromServer = false;
  final _started = DateTime.now();

  /// Writes sent but not yet confirmed. Snapshots cannot show a pending
  /// delete (the document is already gone from them), so count them here.
  int _inFlight = 0;

  @override
  ValueListenable<SyncState> get sync => _sync;

  final _pendingCustomers = ValueNotifier<Set<String>>(const {});

  @override
  ValueListenable<Set<String>> get pendingCustomerIds => _pendingCustomers;

  void _updateSync() {
    if (_disposed) return;
    final cached = _customersCached || _rentalsCached;
    if (!cached) _heardFromServer = true;
    _sync.value = (_customersPending || _rentalsPending || _inFlight > 0)
        ? SyncState.pending
        : !cached
        ? SyncState.synced
        // Give the first connection a moment before saying "offline".
        : !_heardFromServer &&
              DateTime.now().difference(_started) < const Duration(seconds: 8)
        ? SyncState.connecting
        : SyncState.offline;
  }

  @override
  Stream<String> get writeErrors => _errors.stream;

  @override
  Stream<List<Customer>> watchCustomers() =>
      _customers.snapshots(includeMetadataChanges: true).map((snap) {
        _customersPending = snap.metadata.hasPendingWrites;
        _customersCached = snap.metadata.isFromCache;
        _updateSync();
        final pending = {
          for (final d in snap.docs)
            if (d.metadata.hasPendingWrites) d.id,
        };
        if (!setEquals(pending, _pendingCustomers.value)) {
          _pendingCustomers.value = pending;
        }
        return snap.docs.map((d) => Customer.fromMap(d.id, d.data())).toList();
      });

  @override
  Stream<List<Rental>> watchRentals() =>
      _rentals.snapshots(includeMetadataChanges: true).map((snap) {
        _rentalsPending = snap.metadata.hasPendingWrites;
        _rentalsCached = snap.metadata.isFromCache;
        _updateSync();
        final out = <Rental>[];
        for (final d in snap.docs) {
          final r = Rental.tryFromMap(d.id, d.data());
          if (r != null) {
            out.add(r);
          } else {
            debugPrint('FirestoreRepository: skipped malformed rental ${d.id}');
          }
        }
        return out;
      });

  @override
  Future<void> saveCustomer(Customer customer) => _write(
    _customers.doc(customer.id).set(customer.toMap()),
    'save customer',
  );

  @override
  Future<void> deleteCustomer(String id) =>
      _write(_customers.doc(id).delete(), 'delete customer');

  @override
  Future<void> saveRental(Rental rental) =>
      _write(_rentals.doc(rental.id).set(rental.toMap()), 'save delivery');

  @override
  Future<void> deleteRental(String id) =>
      _write(_rentals.doc(id).delete(), 'delete delivery');

  /// Firestore applies writes to the local cache immediately and the
  /// snapshot listeners fire straight away, but the returned future only
  /// completes once the server confirms — which never happens offline.
  /// So we don't await it; we only watch it for errors.
  Future<void> _write(Future<void> op, String what) {
    _inFlight++;
    _updateSync();
    op.whenComplete(() {
      _inFlight--;
      _updateSync();
    }).ignore();
    op.catchError((Object e) {
      debugPrint('FirestoreRepository: failed to $what: $e');
      if (!_errors.isClosed) {
        _errors.add(
          e is FirebaseException && e.code == 'permission-denied'
              ? 'Could not $what: the database refused it. This account may '
                    'not be on the staff list, or the database rules were not '
                    'deployed. Ask the owner to check.'
              : 'Could not $what. Please check your connection.',
        );
      }
    });
    return Future.value();
  }

  @override
  void dispose() {
    _disposed = true;
    _connectTimer?.cancel();
    _errors.close();
    _sync.dispose();
    _pendingCustomers.dispose();
  }
}
