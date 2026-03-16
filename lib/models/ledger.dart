import 'bill.dart';

class LedgerEntry {
  final String materialName;
  double given;
  double returned;
  double get balance => given - returned;

  LedgerEntry(this.materialName, {this.given = 0, this.returned = 0});
}

class LedgerTransaction {
  final DateTime date;
  final String billNumber;
  final String billId;
  final String materialName;
  final double qty; // positive = given, negative = returned
  final bool isReturn;

  const LedgerTransaction({
    required this.date,
    required this.billNumber,
    required this.billId,
    required this.materialName,
    required this.qty,
    required this.isReturn,
  });
}

/// Compute ledger entries and transaction history for a customer.
({List<LedgerEntry> entries, List<LedgerTransaction> transactions})
    computeLedger(List<Bill> bills, String customerId) {
  final entryMap = <String, LedgerEntry>{};
  final txns = <LedgerTransaction>[];

  void addGiven(String name, double qty) {
    entryMap.putIfAbsent(name, () => LedgerEntry(name));
    entryMap[name]!.given += qty;
  }

  void addReturned(String name, double qty) {
    entryMap.putIfAbsent(name, () => LedgerEntry(name));
    entryMap[name]!.returned += qty;
  }

  final customerBills = bills
      .where((b) => b.customerId == customerId && b.customerId.isNotEmpty)
      .toList()
    ..sort((a, b) => a.billDate.compareTo(b.billDate));

  for (final bill in customerBills) {
    // Free-form materials
    for (final m in bill.materials) {
      final qty = m.quantity > 0 ? m.quantity : 1.0;
      addGiven(m.name, qty);
      txns.add(LedgerTransaction(
        date: bill.billDate,
        billNumber: bill.billNumber,
        billId: bill.id,
        materialName: m.name,
        qty: qty,
        isReturn: false,
      ));
      if (m.isReturned) {
        addReturned(m.name, qty);
        txns.add(LedgerTransaction(
          date: m.returnDate ?? bill.billDate,
          billNumber: bill.billNumber,
          billId: bill.id,
          materialName: m.name,
          qty: -qty,
          isReturn: true,
        ));
      }
    }

    // Column boxes
    for (final cb in bill.columnBoxes) {
      final qty = cb.totalQty.toDouble();
      if (qty <= 0) continue;
      final name = 'Col. Box ${cb.sizeKey}';
      addGiven(name, qty);
      txns.add(LedgerTransaction(
        date: bill.billDate,
        billNumber: bill.billNumber,
        billId: bill.id,
        materialName: name,
        qty: qty,
        isReturn: false,
      ));
      if (cb.isReturned) {
        addReturned(name, qty);
        txns.add(LedgerTransaction(
          date: cb.returnDate ?? bill.billDate,
          billNumber: bill.billNumber,
          billId: bill.id,
          materialName: name,
          qty: -qty,
          isReturn: true,
        ));
      }
    }

    // Round boxes
    for (final rb in bill.roundBoxes) {
      final qty = rb.totalQty.toDouble();
      if (qty <= 0) continue;
      final name = 'Round Box ${rb.sizeKey}';
      addGiven(name, qty);
      txns.add(LedgerTransaction(
        date: bill.billDate,
        billNumber: bill.billNumber,
        billId: bill.id,
        materialName: name,
        qty: qty,
        isReturn: false,
      ));
      if (rb.isReturned) {
        addReturned(name, qty);
        txns.add(LedgerTransaction(
          date: rb.returnDate ?? bill.billDate,
          billNumber: bill.billNumber,
          billId: bill.id,
          materialName: name,
          qty: -qty,
          isReturn: true,
        ));
      }
    }
  }

  // Sort transactions: newest first
  txns.sort((a, b) => b.date.compareTo(a.date));

  // Sort entries: pending items first (balance > 0), then by name
  final entries = entryMap.values.toList()
    ..sort((a, b) {
      if (a.balance > 0 && b.balance <= 0) return -1;
      if (a.balance <= 0 && b.balance > 0) return 1;
      return a.materialName.compareTo(b.materialName);
    });

  return (entries: entries, transactions: txns);
}

String fmtQty(double qty) {
  final abs = qty.abs();
  return abs == abs.truncateToDouble()
      ? abs.toInt().toString()
      : abs.toStringAsFixed(1);
}
