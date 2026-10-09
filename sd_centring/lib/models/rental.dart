import '../core/dates.dart';
import '../core/quantity.dart';

/// One line on a delivery challan: what material went out and how much.
class RentalItem {
  final String id;
  final String name;
  final double qty;
  final String unit;

  const RentalItem({
    required this.id,
    required this.name,
    required this.qty,
    this.unit = 'pcs',
  });

  RentalItem copyWith({String? name, double? qty, String? unit}) => RentalItem(
    id: id,
    name: name ?? this.name,
    qty: qty ?? this.qty,
    unit: unit ?? this.unit,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'qty': qty,
    'unit': unit,
  };

  static RentalItem? tryFromMap(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final name = raw['name'];
    final qty = raw['qty'];
    if (id is! String || name is! String || qty is! num) return null;
    final unit = raw['unit'];
    return RentalItem(
      id: id,
      name: name,
      qty: qty.toDouble(),
      unit: unit is String && unit.isNotEmpty ? unit : 'pcs',
    );
  }
}

/// Material that came back. Several partial returns per item are allowed.
class ReturnEntry {
  final String id;
  final String itemId;
  final double qty;
  final DateTime date;
  final String note;

  const ReturnEntry({
    required this.id,
    required this.itemId,
    required this.qty,
    required this.date,
    this.note = '',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'itemId': itemId,
    'qty': qty,
    'date': toIsoDay(date),
    'note': note,
  };

  static ReturnEntry? tryFromMap(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final itemId = raw['itemId'];
    final qty = raw['qty'];
    final date = tryParseIsoDay(raw['date']);
    if (id is! String || itemId is! String || qty is! num || date == null) {
      return null;
    }
    final note = raw['note'];
    return ReturnEntry(
      id: id,
      itemId: itemId,
      qty: qty.toDouble(),
      date: date,
      note: note is String ? note : '',
    );
  }
}

/// Audit trail entry for every change of the expiry date.
class ExpiryChange {
  final DateTime from;
  final DateTime to;
  final DateTime changedAt;

  const ExpiryChange({
    required this.from,
    required this.to,
    required this.changedAt,
  });

  Map<String, dynamic> toMap() => {
    'from': toIsoDay(from),
    'to': toIsoDay(to),
    'changedAt': changedAt.millisecondsSinceEpoch,
  };

  static ExpiryChange? tryFromMap(Object? raw) {
    if (raw is! Map) return null;
    final from = tryParseIsoDay(raw['from']);
    final to = tryParseIsoDay(raw['to']);
    final at = raw['changedAt'];
    if (from == null || to == null || at is! int) return null;
    return ExpiryChange(
      from: from,
      to: to,
      changedAt: DateTime.fromMillisecondsSinceEpoch(at),
    );
  }
}

/// A delivery challan (DC): material sent to a customer's site that must
/// come back by [expiresOn]. There are deliberately no prices or amounts.
class Rental {
  final String id;
  final String dcNumber;
  final String customerId;

  /// Snapshot of the customer's name when saved; the live customer record is
  /// preferred for display.
  final String customerName;
  final String site;
  final DateTime issuedOn;
  final DateTime expiresOn;
  final List<RentalItem> items;
  final List<ReturnEntry> returns;
  final List<ExpiryChange> expiryHistory;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Rental({
    required this.id,
    required this.dcNumber,
    required this.customerId,
    required this.customerName,
    this.site = '',
    required this.issuedOn,
    required this.expiresOn,
    required this.items,
    this.returns = const [],
    this.expiryHistory = const [],
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
  });

  double returnedQty(String itemId) => roundQty(
    returns.where((r) => r.itemId == itemId).fold(0.0, (sum, r) => sum + r.qty),
  );

  double outstandingQty(RentalItem item) {
    final left = roundQty(item.qty - returnedQty(item.id));
    return left < 0 ? 0 : left;
  }

  List<RentalItem> get outstandingItems =>
      items.where((i) => !qtyIsZero(outstandingQty(i))).toList();

  /// Closed once every item has fully come back.
  bool get isClosed => items.isNotEmpty && outstandingItems.isEmpty;

  /// The date the last material came back, for closed rentals.
  DateTime? get closedOn {
    if (!isClosed || returns.isEmpty) return null;
    return returns.map((r) => r.date).reduce((a, b) => a.isAfter(b) ? a : b);
  }

  Rental copyWith({
    String? dcNumber,
    String? customerId,
    String? customerName,
    String? site,
    DateTime? issuedOn,
    DateTime? expiresOn,
    List<RentalItem>? items,
    List<ReturnEntry>? returns,
    List<ExpiryChange>? expiryHistory,
    String? notes,
    DateTime? updatedAt,
  }) => Rental(
    id: id,
    dcNumber: dcNumber ?? this.dcNumber,
    customerId: customerId ?? this.customerId,
    customerName: customerName ?? this.customerName,
    site: site ?? this.site,
    issuedOn: issuedOn ?? this.issuedOn,
    expiresOn: expiresOn ?? this.expiresOn,
    items: items ?? this.items,
    returns: returns ?? this.returns,
    expiryHistory: expiryHistory ?? this.expiryHistory,
    notes: notes ?? this.notes,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// Items, returns and history are stored as native lists of maps — never
  /// as JSON strings — so they stay queryable and readable in the console.
  Map<String, dynamic> toMap() => {
    'dcNumber': dcNumber,
    'customerId': customerId,
    'customerName': customerName,
    'site': site,
    'issuedOn': toIsoDay(issuedOn),
    'expiresOn': toIsoDay(expiresOn),
    'items': items.map((i) => i.toMap()).toList(),
    'returns': returns.map((r) => r.toMap()).toList(),
    'expiryHistory': expiryHistory.map((e) => e.toMap()).toList(),
    'notes': notes,
    'closed': isClosed,
    'createdAt': createdAt.millisecondsSinceEpoch,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
  };

  /// Returns null when the document is missing required fields, so a
  /// corrupt record is skipped instead of crashing the app.
  static Rental? tryFromMap(String id, Map<String, dynamic> m) {
    final dc = m['dcNumber'];
    final customerId = m['customerId'];
    final issued = tryParseIsoDay(m['issuedOn']);
    final expires = tryParseIsoDay(m['expiresOn']);
    if (dc is! String ||
        customerId is! String ||
        issued == null ||
        expires == null) {
      return null;
    }
    List<T> list<T>(Object? raw, T? Function(Object?) parse) =>
        raw is List ? raw.map(parse).whereType<T>().toList() : <T>[];
    DateTime millis(Object? v) => v is int
        ? DateTime.fromMillisecondsSinceEpoch(v)
        : DateTime.fromMillisecondsSinceEpoch(0);
    String str(Object? v) => v is String ? v : '';

    return Rental(
      id: id,
      dcNumber: dc,
      customerId: customerId,
      customerName: str(m['customerName']),
      site: str(m['site']),
      issuedOn: issued,
      expiresOn: expires,
      items: list(m['items'], RentalItem.tryFromMap),
      returns: list(m['returns'], ReturnEntry.tryFromMap),
      expiryHistory: list(m['expiryHistory'], ExpiryChange.tryFromMap),
      notes: str(m['notes']),
      createdAt: millis(m['createdAt']),
      updatedAt: millis(m['updatedAt']),
    );
  }
}
