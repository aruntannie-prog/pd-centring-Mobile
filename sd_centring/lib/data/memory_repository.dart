import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/customer.dart';
import '../models/rental.dart';
import 'repository.dart';

/// In-memory storage, used for tests and for demo mode when Firebase has not
/// been configured yet. Nothing is persisted.
class MemoryRepository implements Repository {
  MemoryRepository({
    Iterable<Customer> customers = const [],
    Iterable<Rental> rentals = const [],
  }) {
    for (final c in customers) {
      _customers[c.id] = c;
    }
    for (final r in rentals) {
      _rentals[r.id] = r;
    }
  }

  final _customers = <String, Customer>{};
  final _rentals = <String, Rental>{};
  final _customerCtrl = StreamController<List<Customer>>.broadcast();
  final _rentalCtrl = StreamController<List<Rental>>.broadcast();
  final _errors = StreamController<String>.broadcast();

  @override
  bool get isDemo => true;

  @override
  final ValueListenable<SyncState> sync = ValueNotifier(SyncState.demo);

  /// Always empty in demo mode; tests and the screenshot tool set it to
  /// show the "not in the cloud yet" state.
  final pendingCustomers = ValueNotifier<Set<String>>(const {});

  @override
  ValueListenable<Set<String>> get pendingCustomerIds => pendingCustomers;

  @override
  Stream<String> get writeErrors => _errors.stream;

  @override
  Stream<List<Customer>> watchCustomers() =>
      _replay(_customerCtrl, () => _customers.values.toList());

  @override
  Stream<List<Rental>> watchRentals() =>
      _replay(_rentalCtrl, () => _rentals.values.toList());

  /// Emits the current snapshot to each new listener, then live updates.
  Stream<List<T>> _replay<T>(
    StreamController<List<T>> ctrl,
    List<T> Function() current,
  ) {
    return Stream.multi((listener) {
      listener.add(current());
      final sub = ctrl.stream.listen(listener.add, onError: listener.addError);
      listener.onCancel = sub.cancel;
    });
  }

  @override
  Future<void> saveCustomer(Customer customer) async {
    _customers[customer.id] = customer;
    _customerCtrl.add(_customers.values.toList());
  }

  @override
  Future<void> deleteCustomer(String id) async {
    _customers.remove(id);
    _customerCtrl.add(_customers.values.toList());
  }

  @override
  Future<void> saveRental(Rental rental) async {
    _rentals[rental.id] = rental;
    _rentalCtrl.add(_rentals.values.toList());
  }

  @override
  Future<void> deleteRental(String id) async {
    _rentals.remove(id);
    _rentalCtrl.add(_rentals.values.toList());
  }

  @override
  void dispose() {
    _customerCtrl.close();
    _rentalCtrl.close();
    _errors.close();
    pendingCustomers.dispose();
  }
}
