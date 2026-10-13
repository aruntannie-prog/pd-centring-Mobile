import 'package:flutter/foundation.dart';

import '../models/customer.dart';
import '../models/rental.dart';

/// Storage abstraction. The UI never talks to Firestore directly, which keeps
/// screens testable with [MemoryRepository].
///
/// Write methods return as soon as the change is applied locally. With
/// Firestore that means they do not wait for the server, so the app never
/// hangs while offline; failures are reported on [writeErrors].
abstract class Repository {
  Stream<List<Customer>> watchCustomers();
  Stream<List<Rental>> watchRentals();

  Future<void> saveCustomer(Customer customer);
  Future<void> deleteCustomer(String id);

  Future<void> saveRental(Rental rental);
  Future<void> deleteRental(String id);

  /// Human-readable messages for writes that failed after the fact.
  Stream<String> get writeErrors;

  /// True when data only lives in memory (no Firebase configured).
  bool get isDemo;

  /// Whether local changes have reached the cloud. Shown in the UI so a
  /// device that silently stops syncing is noticed the same day.
  ValueListenable<SyncState> get sync;

  /// Customers whose latest change is saved on this device but not yet
  /// confirmed by the server. Shown on each customer, so a record that
  /// never reached the cloud is visible instead of silently local.
  ValueListenable<Set<String>> get pendingCustomerIds;

  void dispose();
}

enum SyncState {
  /// Just started; the server has not answered yet.
  connecting,

  /// Everything on this device is confirmed by the server.
  synced,

  /// Changes made on this device have not been confirmed by the server yet.
  pending,

  /// Showing cached data; the server cannot be reached.
  offline,

  /// Demo mode: nothing is saved anywhere.
  demo,
}
