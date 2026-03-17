import 'package:uuid/uuid.dart';

const _uuid = Uuid();

enum BillType { bill, dc }

enum MaterialStatus { pending, returned }

class RentalMaterial {
  final String id;
  String name;
  int days;
  DateTime dueDate;
  MaterialStatus status;
  double quantity;
  String unit;
  double rate;
  DateTime? returnDate;

  double get amount => quantity * rate;

  RentalMaterial({
    String? id,
    required this.name,
    required this.days,
    required this.dueDate,
    this.status = MaterialStatus.pending,
    this.quantity = 0.0,
    this.unit = 'pcs',
    this.rate = 0.0,
    this.returnDate,
  }) : id = id ?? _uuid.v4();

  bool get isPending => status == MaterialStatus.pending;
  bool get isReturned => status == MaterialStatus.returned;

  String get dueDateFormatted {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${dueDate.day} ${months[dueDate.month - 1]} ${dueDate.year}';
  }

  RentalMaterial copyWith({MaterialStatus? status, DateTime? returnDate}) => RentalMaterial(
        id: id,
        name: name,
        days: days,
        dueDate: dueDate,
        status: status ?? this.status,
        quantity: quantity,
        unit: unit,
        rate: rate,
        returnDate: returnDate ?? this.returnDate,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'days': days,
        'dueDate': dueDate.toIso8601String(),
        'status': status.name,
        'quantity': quantity,
        'unit': unit,
        'rate': rate,
        'returnDate': returnDate?.toIso8601String(),
      };

  factory RentalMaterial.fromJson(Map<String, dynamic> j) => RentalMaterial(
        id: j['id'],
        name: j['name'],
        days: j['days'],
        dueDate: DateTime.parse(j['dueDate']),
        status: MaterialStatus.values.firstWhere((e) => e.name == j['status'],
            orElse: () => MaterialStatus.pending),
        quantity: (j['quantity'] as num?)?.toDouble() ?? 0.0,
        unit: j['unit'] as String? ?? 'pcs',
        rate: (j['rate'] as num?)?.toDouble() ?? 0.0,
        returnDate: j['returnDate'] != null ? DateTime.tryParse(j['returnDate']) : null,
      );
}

// ── NEW: Mixed Invoice Elements ──────────────────────────────────────────────

class ColumnHeightRow {
  int heightFt;
  int qty;
  double rate;
  final int days;

  double get amount => qty * rate;

  ColumnHeightRow({required this.heightFt, required this.qty, required this.rate, this.days = 0});

  Map<String, dynamic> toJson() => {
        'heightFt': heightFt,
        'qty': qty,
        'rate': rate,
        'days': days,
      };

  factory ColumnHeightRow.fromJson(Map<String, dynamic> j) => ColumnHeightRow(
        heightFt: j['heightFt'] as int,
        qty: j['qty'] as int,
        rate: (j['rate'] as num).toDouble(),
        days: j['days'] as int? ?? 0,
      );
}

class ColumnShoeRow {
  int qty;
  double rate;
  int days;

  double get amount => qty * rate;

  ColumnShoeRow({required this.qty, required this.rate, this.days = 0});

  Map<String, dynamic> toJson() => {
        'qty': qty,
        'rate': rate,
        'days': days,
      };

  factory ColumnShoeRow.fromJson(Map<String, dynamic> j) => ColumnShoeRow(
        qty: j['qty'] as int,
        rate: (j['rate'] as num).toDouble(),
        days: j['days'] as int? ?? 0,
      );
}

class ColumnSizeBlock {
  String sizeKey;
  List<ColumnHeightRow> heightRows;
  ColumnShoeRow? shoe;
  int days;
  bool isReturned;
  DateTime? returnDate;

  double get totalAmount {
    double s = 0;
    for (var r in heightRows) { s += r.amount; }
    if (shoe != null) s += shoe!.amount;
    return s;
  }

  int get totalQty {
    int q = 0;
    for (var r in heightRows) { q += r.qty; }
    if (shoe != null) q += shoe!.qty;
    return q;
  }

  int get maxRowDays {
    var m = heightRows.fold(0, (acc, r) => r.days > acc ? r.days : acc);
    if (shoe != null && shoe!.days > m) m = shoe!.days;
    if (m == 0) return days; // fallback to block-level days for old records
    return m;
  }

  ColumnSizeBlock({
    required this.sizeKey,
    required this.heightRows,
    this.shoe,
    this.days = 0,
    this.isReturned = false,
    this.returnDate,
  });

  ColumnSizeBlock copyWith({bool? isReturned, DateTime? returnDate}) => ColumnSizeBlock(
        sizeKey: sizeKey,
        heightRows: heightRows,
        shoe: shoe,
        days: days,
        isReturned: isReturned ?? this.isReturned,
        returnDate: returnDate ?? this.returnDate,
      );

  Map<String, dynamic> toJson() => {
        'sizeKey': sizeKey,
        'heightRows': heightRows.map((e) => e.toJson()).toList(),
        'shoe': shoe?.toJson(),
        'days': days,
        'isReturned': isReturned,
        'returnDate': returnDate?.toIso8601String(),
      };

  factory ColumnSizeBlock.fromJson(Map<String, dynamic> j) => ColumnSizeBlock(
        sizeKey: j['sizeKey'] as String,
        heightRows: (j['heightRows'] as List?)?.map((e) => ColumnHeightRow.fromJson(Map<String, dynamic>.from(e))).toList() ?? [],
        shoe: j['shoe'] != null ? ColumnShoeRow.fromJson(Map<String, dynamic>.from(j['shoe'])) : null,
        days: j['days'] as int? ?? 0,
        isReturned: j['isReturned'] as bool? ?? false,
        returnDate: j['returnDate'] != null ? DateTime.tryParse(j['returnDate']) : null,
      );
}

// ── Side Sheet ────────────────────────────────────────────────────────────────

class SideSheetEntry {
  final String sheetType; // '24', '21', '18', '15', '12', '9'
  final int size;         // 8, 7, 6, 5, 4, 3, 2
  final int qty;
  final double rate;      // ₹ per sqft for this sheet type
  final int days;         // rental due date (not a multiplier)
  final bool isReturned;
  final DateTime? returnDate;

  static const Map<String, double> conversionFactors = {
    '24': 2.00,
    '21': 1.75,
    '18': 1.50,
    '15': 1.25,
    '12': 1.00,
    '9':  0.75,
  };

  double get convFactor => conversionFactors[sheetType] ?? 1.0;
  double get sqft => size * qty * convFactor;
  double get amount => sqft * rate;

  const SideSheetEntry({
    required this.sheetType,
    required this.size,
    required this.qty,
    this.rate = 0.0,
    this.days = 0,
    this.isReturned = false,
    this.returnDate,
  });

  SideSheetEntry copyWith({
    String? sheetType,
    int? size,
    int? qty,
    double? rate,
    int? days,
    bool? isReturned,
    DateTime? returnDate,
  }) {
    return SideSheetEntry(
      sheetType: sheetType ?? this.sheetType,
      size: size ?? this.size,
      qty: qty ?? this.qty,
      rate: rate ?? this.rate,
      days: days ?? this.days,
      isReturned: isReturned ?? this.isReturned,
      returnDate: returnDate ?? this.returnDate,
    );
  }

  Map<String, dynamic> toJson() => {
        'sheetType': sheetType,
        'size': size,
        'qty': qty,
        'rate': rate,
        'days': days,
        'isReturned': isReturned,
        'returnDate': returnDate?.toIso8601String(),
      };

  factory SideSheetEntry.fromJson(Map<String, dynamic> j, {double fallbackRate = 0.0}) =>
      SideSheetEntry(
        sheetType: j['sheetType'] as String,
        size: j['size'] as int,
        qty: j['qty'] as int,
        rate: (j['rate'] as num?)?.toDouble() ?? fallbackRate,
        days: j['days'] as int? ?? 0,
        isReturned: j['isReturned'] as bool? ?? false,
        returnDate: j['returnDate'] != null ? DateTime.tryParse(j['returnDate']) : null,
      );
}

// ── NEW: Palagai, Muttu, and Roof Material ──────────────────────────────────

class PalagaiEntry {
  final String length;
  final String size;
  final int qty;
  final double rate;
  final int days;
  final bool isReturned;
  final DateTime? returnDate;

  double get amount => qty * rate;

  const PalagaiEntry({
    required this.length,
    required this.size,
    required this.qty,
    this.rate = 0.0,
    this.days = 0,
    this.isReturned = false,
    this.returnDate,
  });

  PalagaiEntry copyWith({bool? isReturned, DateTime? returnDate}) => PalagaiEntry(
        length: length,
        size: size,
        qty: qty,
        rate: rate,
        days: days,
        isReturned: isReturned ?? this.isReturned,
        returnDate: returnDate ?? this.returnDate,
      );

  Map<String, dynamic> toJson() => {
        'length': length,
        'size': size,
        'qty': qty,
        'rate': rate,
        'days': days,
        'isReturned': isReturned,
        'returnDate': returnDate?.toIso8601String(),
      };

  factory PalagaiEntry.fromJson(Map<String, dynamic> j) => PalagaiEntry(
        length: j['length'] as String,
        size: j['size'].toString(),
        qty: j['qty'] as int,
        rate: (j['rate'] as num?)?.toDouble() ?? 0.0,
        days: j['days'] as int? ?? 0,
        isReturned: j['isReturned'] as bool? ?? false,
        returnDate: j['returnDate'] != null ? DateTime.tryParse(j['returnDate']) : null,
      );
}

class MuttuEntry {
  final String length;
  final String size;
  final int qty;
  final double rate;
  final int days;
  final bool isReturned;
  final DateTime? returnDate;

  double get amount => qty * rate;

  const MuttuEntry({
    required this.length,
    required this.size,
    required this.qty,
    this.rate = 0.0,
    this.days = 0,
    this.isReturned = false,
    this.returnDate,
  });

  MuttuEntry copyWith({bool? isReturned, DateTime? returnDate}) => MuttuEntry(
        length: length,
        size: size,
        qty: qty,
        rate: rate,
        days: days,
        isReturned: isReturned ?? this.isReturned,
        returnDate: returnDate ?? this.returnDate,
      );

  Map<String, dynamic> toJson() => {
        'length': length,
        'size': size,
        'qty': qty,
        'rate': rate,
        'days': days,
        'isReturned': isReturned,
        'returnDate': returnDate?.toIso8601String(),
      };

  factory MuttuEntry.fromJson(Map<String, dynamic> j) => MuttuEntry(
        length: j['length'] as String,
        size: j['size'].toString(),
        qty: j['qty'] as int,
        rate: (j['rate'] as num?)?.toDouble() ?? 0.0,
        days: j['days'] as int? ?? 0,
        isReturned: j['isReturned'] as bool? ?? false,
        returnDate: j['returnDate'] != null ? DateTime.tryParse(j['returnDate']) : null,
      );
}

class RoofMaterialEntry {
  final String itemName;
  final int qty;
  final double rate;
  final int days;
  final bool isReturned;
  final DateTime? returnDate;

  double get amount => qty * rate;

  const RoofMaterialEntry({
    required this.itemName,
    required this.qty,
    this.rate = 0.0,
    this.days = 0,
    this.isReturned = false,
    this.returnDate,
  });

  RoofMaterialEntry copyWith({bool? isReturned, DateTime? returnDate}) => RoofMaterialEntry(
        itemName: itemName,
        qty: qty,
        rate: rate,
        days: days,
        isReturned: isReturned ?? this.isReturned,
        returnDate: returnDate ?? this.returnDate,
      );

  Map<String, dynamic> toJson() => {
        'itemName': itemName,
        'qty': qty,
        'rate': rate,
        'days': days,
        'isReturned': isReturned,
        'returnDate': returnDate?.toIso8601String(),
      };

  factory RoofMaterialEntry.fromJson(Map<String, dynamic> j) => RoofMaterialEntry(
        itemName: j['itemName'] as String,
        qty: j['qty'] as int,
        rate: (j['rate'] as num?)?.toDouble() ?? 0.0,
        days: j['days'] as int? ?? 0,
        isReturned: j['isReturned'] as bool? ?? false,
        returnDate: j['returnDate'] != null ? DateTime.tryParse(j['returnDate']) : null,
      );
}

enum BillStatus { allPending, partial, allReturned, dc, billedDC, overdue }

class Bill {
  final String id;
  String billNumber;
  BillType type;
  String customerName;
  String customerId;
  String site;
  DateTime billDate;
  String branch;
  List<RentalMaterial> materials;
  List<ColumnSizeBlock> columnBoxes;
  List<ColumnSizeBlock> roundBoxes;
  double vehicleChargeUp;
  double vehicleChargeDown;
  double labourChargeUp;
  double labourChargeDown;
  bool gstEnabled;
  double advancePaid;
  bool isBilled;
  String? parentId;
  List<String> linkedDcIds;
  List<SideSheetEntry> sideSheets;
  double sideSheetRate;
  
  List<PalagaiEntry> palagai;
  List<MuttuEntry> muttu;
  List<RoofMaterialEntry> roofItems;

  double get rentTotal {
    final mTotal = materials.fold(0.0, (s, m) => s + m.amount);
    final cTotal = columnBoxes.fold(0.0, (s, b) => s + b.totalAmount);
    final rTotal = roundBoxes.fold(0.0, (s, b) => s + b.totalAmount);
    final ssTotal = sideSheets.fold(0.0, (s, e) => s + e.amount);
    final palagaiTotal = palagai.fold(0.0, (s, e) => s + e.amount);
    final muttuTotal = muttu.fold(0.0, (s, e) => s + e.amount);
    final roofTotal = roofItems.fold(0.0, (s, e) => s + e.amount);
    
    return mTotal + cTotal + rTotal + ssTotal + palagaiTotal + muttuTotal + roofTotal;
  }
  
  double get grandTotal => rentTotal + vehicleChargeUp + vehicleChargeDown + labourChargeUp + labourChargeDown;
  double get sgst => gstEnabled ? grandTotal * 0.09 : 0.0;
  double get cgst => gstEnabled ? grandTotal * 0.09 : 0.0;
  double get totalWithGst => grandTotal + sgst + cgst;
  double get balanceDue => totalWithGst - advancePaid;

  Bill({
    String? id,
    required this.billNumber,
    required this.type,
    required this.customerName,
    required this.customerId,
    required this.site,
    required this.billDate,
    this.branch = '',
    required this.materials,
    this.columnBoxes = const [],
    this.roundBoxes = const [],
    this.vehicleChargeUp = 0.0,
    this.vehicleChargeDown = 0.0,
    this.labourChargeUp = 0.0,
    this.labourChargeDown = 0.0,
    this.gstEnabled = false,
    this.advancePaid = 0.0,
    this.isBilled = false,
    this.parentId,
    this.linkedDcIds = const [],
    this.sideSheets = const [],
    this.sideSheetRate = 0.0,
    this.palagai = const [],
    this.muttu = const [],
    this.roofItems = const [],
  }) : id = id ?? _uuid.v4();

  bool get _hasAnyItems =>
      materials.isNotEmpty || columnBoxes.isNotEmpty || roundBoxes.isNotEmpty || 
      sideSheets.isNotEmpty || palagai.isNotEmpty || muttu.isNotEmpty || roofItems.isNotEmpty;

  bool get _allItemsReturned {
    if (!_hasAnyItems) return false;
    final matOk = materials.isEmpty || materials.every((m) => m.isReturned);
    final cbOk = columnBoxes.isEmpty || columnBoxes.every((b) => b.isReturned);
    final rbOk = roundBoxes.isEmpty || roundBoxes.every((b) => b.isReturned);
    final ssOk = sideSheets.isEmpty || sideSheets.every((e) => e.isReturned);
    final palagaiOk = palagai.isEmpty || palagai.every((e) => e.isReturned);
    final muttuOk = muttu.isEmpty || muttu.every((e) => e.isReturned);
    final roofOk = roofItems.isEmpty || roofItems.every((e) => e.isReturned);
    
    return matOk && cbOk && rbOk && ssOk && palagaiOk && muttuOk && roofOk;
  }

  bool get _someItemsReturned =>
      materials.any((m) => m.isReturned) ||
      columnBoxes.any((b) => b.isReturned) ||
      roundBoxes.any((b) => b.isReturned) ||
      sideSheets.any((e) => e.isReturned) ||
      palagai.any((e) => e.isReturned) ||
      muttu.any((e) => e.isReturned) ||
      roofItems.any((e) => e.isReturned);

  // Returns the earliest due date among all non-returned items
  DateTime? get dueDate {
    final dates = <DateTime>[];
    for (final m in materials) {
      if (!m.isReturned) dates.add(m.dueDate);
    }
    for (final cb in columnBoxes) {
      if (!cb.isReturned) {
        final d = cb.maxRowDays > 0 ? cb.maxRowDays : cb.days;
        if (d > 0) dates.add(billDate.add(Duration(days: d)));
      }
    }
    for (final rb in roundBoxes) {
      if (!rb.isReturned) {
        final d = rb.maxRowDays > 0 ? rb.maxRowDays : rb.days;
        if (d > 0) dates.add(billDate.add(Duration(days: d)));
      }
    }
    for (final p in palagai) {
      if (!p.isReturned && p.days > 0) dates.add(billDate.add(Duration(days: p.days)));
    }
    for (final m in muttu) {
      if (!m.isReturned && m.days > 0) dates.add(billDate.add(Duration(days: m.days)));
    }
    for (final r in roofItems) {
      if (!r.isReturned && r.days > 0) dates.add(billDate.add(Duration(days: r.days)));
    }
    for (final s in sideSheets) {
      if (!s.isReturned && s.days > 0) dates.add(billDate.add(Duration(days: s.days)));
    }
    if (dates.isEmpty) return null;
    return dates.reduce((a, b) => a.isBefore(b) ? a : b);
  }

  bool get isOverdue {
    final dd = dueDate;
    if (dd == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dd.year, dd.month, dd.day);
    return today.isAfter(due);
  }

  int get overdueDays {
    final dd = dueDate;
    if (dd == null) return 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dd.year, dd.month, dd.day);
    return today.isAfter(due) ? today.difference(due).inDays : 0;
  }

  String? get dueDateFormatted {
    final dd = dueDate;
    if (dd == null) return null;
    const mo = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${dd.day} ${mo[dd.month - 1]}';
  }

  BillStatus get status {
    if (type == BillType.dc && isBilled) return BillStatus.billedDC;
    if (!_hasAnyItems) return BillStatus.allPending;
    if (_allItemsReturned) return BillStatus.allReturned;
    if (isOverdue) return BillStatus.overdue;
    if (_someItemsReturned) return BillStatus.partial;
    return BillStatus.allPending;
  }

  bool get isClosed => status == BillStatus.allReturned;
  int get returnedCount =>
      materials.where((m) => m.isReturned).length +
      columnBoxes.where((b) => b.isReturned).length +
      roundBoxes.where((b) => b.isReturned).length +
      sideSheets.where((e) => e.isReturned).length +
      palagai.where((e) => e.isReturned).length +
      muttu.where((e) => e.isReturned).length +
      roofItems.where((e) => e.isReturned).length;

  String get billDateFormatted {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${billDate.day} ${months[billDate.month - 1]} ${billDate.year}';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'billNumber': billNumber,
        'type': type.name,
        'customerName': customerName,
        'customerId': customerId,
        'site': site,
        'billDate': billDate.toIso8601String(),
        'branch': branch,
        'materials': materials.map((m) => m.toJson()).toList(),
        'columnBoxes': columnBoxes.map((b) => b.toJson()).toList(),
        'roundBoxes': roundBoxes.map((b) => b.toJson()).toList(),
        'vehicleChargeUp': vehicleChargeUp,
        'vehicleChargeDown': vehicleChargeDown,
        'labourChargeUp': labourChargeUp,
        'labourChargeDown': labourChargeDown,
        'gstEnabled': gstEnabled,
        'advancePaid': advancePaid,
        'isBilled': isBilled,
        'parentId': parentId,
        'linkedDcIds': linkedDcIds,
        'sideSheets': sideSheets.map((e) => e.toJson()).toList(),
        'sideSheetRate': sideSheetRate,
        'palagai': palagai.map((e) => e.toJson()).toList(),
        'muttu': muttu.map((e) => e.toJson()).toList(),
        'roofItems': roofItems.map((e) => e.toJson()).toList(),
      };

  factory Bill.fromJson(Map<String, dynamic> j) => Bill(
        id: j['id'],
        billNumber: j['billNumber'],
        type: BillType.values.firstWhere((e) => e.name == j['type'],
            orElse: () => BillType.bill),
        customerName: j['customerName'] ?? 'Unknown',
        customerId: j['customerId'] ?? '',
        site: j['site'] ?? '',
        billDate: DateTime.tryParse(j['billDate']?.toString() ?? '') ??
            DateTime.now(),
        branch: j['branch'] ?? '',
        materials: (j['materials'] as List?)
                ?.map((m) => RentalMaterial.fromJson(m))
                .toList() ??
            [],
        columnBoxes: (j['columnBoxes'] as List?)
                ?.map((b) => ColumnSizeBlock.fromJson(Map<String, dynamic>.from(b)))
                .toList() ??
            [],
        roundBoxes: (j['roundBoxes'] as List?)
                ?.map((b) => ColumnSizeBlock.fromJson(Map<String, dynamic>.from(b)))
                .toList() ??
            [],
        vehicleChargeUp: (j['vehicleChargeUp'] as num?)?.toDouble() ?? 0.0,
        vehicleChargeDown: (j['vehicleChargeDown'] as num?)?.toDouble() ?? 0.0,
        labourChargeUp: (j['labourChargeUp'] as num?)?.toDouble() ?? 0.0,
        labourChargeDown: (j['labourChargeDown'] as num?)?.toDouble() ?? 0.0,
        gstEnabled: j['gstEnabled'] as bool? ?? false,
        advancePaid: (j['advancePaid'] as num?)?.toDouble() ?? 0.0,
        isBilled: j['isBilled'] as bool? ?? false,
        parentId: j['parentId'] as String?,
        linkedDcIds: List<String>.from(j['linkedDcIds'] ?? []),
        sideSheetRate: (j['sideSheetRate'] as num?)?.toDouble() ?? 0.0,
        sideSheets: (j['sideSheets'] as List?)
                ?.map((e) => SideSheetEntry.fromJson(
                      Map<String, dynamic>.from(e),
                      fallbackRate: (j['sideSheetRate'] as num?)?.toDouble() ?? 0.0,
                    ))
                .toList() ??
            [],
        palagai: (j['palagai'] as List?)
                ?.map((e) => PalagaiEntry.fromJson(Map<String, dynamic>.from(e)))
                .toList() ??
            [],
        muttu: (j['muttu'] as List?)
                ?.map((e) => MuttuEntry.fromJson(Map<String, dynamic>.from(e)))
                .toList() ??
            [],
        roofItems: (j['roofItems'] as List?)
                ?.map((e) => RoofMaterialEntry.fromJson(Map<String, dynamic>.from(e)))
                .toList() ??
            [],
      );
}

// Sample data
List<Bill> sampleBills() {
  final now = DateTime(2026, 2, 19);
  return [
    Bill(
      id: 'B6051',
      billNumber: 'Bill #6051',
      type: BillType.bill,
      customerName: 'Palani',
      customerId: '',
      site: 'Muggapair',
      billDate: now,
      materials: [],
      columnBoxes: [],
      roundBoxes: [],
    ),
    Bill(
      id: 'B6050',
      billNumber: 'Bill #6050',
      type: BillType.bill,
      customerName: 'Rajasekar',
      customerId: '',
      site: 'Velachery',
      billDate: now.subtract(const Duration(days: 1)),
      materials: [
        RentalMaterial(
            name: 'Box', days: 20, dueDate: now.add(const Duration(days: 19))),
        RentalMaterial(
            name: 'Roof Material',
            days: 20,
            dueDate: now.add(const Duration(days: 19))),
      ],
    ),
    Bill(
      id: 'B6048',
      billNumber: 'Bill #6048',
      type: BillType.bill,
      customerName: 'Veeraswamy',
      customerId: '',
      site: 'Kovilambakkam',
      billDate: now.subtract(const Duration(days: 5)),
      materials: [
        RentalMaterial(
            name: 'Box',
            days: 20,
            dueDate: now.add(const Duration(days: 15)),
            status: MaterialStatus.returned),
        RentalMaterial(
            name: 'Palagai',
            days: 30,
            dueDate: now.add(const Duration(days: 25))),
      ],
    ),
    Bill(
      id: 'B6045',
      billNumber: 'Bill #6045',
      type: BillType.bill,
      customerName: 'Mohan',
      customerId: '',
      site: 'Vellaikal',
      billDate: now.subtract(const Duration(days: 9)),
      materials: [
        RentalMaterial(
            name: 'Roof Material',
            days: 20,
            dueDate: now.add(const Duration(days: 11)),
            status: MaterialStatus.returned),
        RentalMaterial(
            name: 'Side Sheet',
            days: 20,
            dueDate: now.add(const Duration(days: 11)),
            status: MaterialStatus.returned),
      ],
    ),
    Bill(
      id: 'B6043',
      billNumber: 'Bill #6043',
      type: BillType.bill,
      customerName: 'Sakthivel',
      customerId: '',
      site: 'Vadakupet',
      billDate: now.subtract(const Duration(days: 11)),
      materials: [
        RentalMaterial(
            name: 'Box', days: 45, dueDate: now.add(const Duration(days: 34))),
      ],
    ),
    Bill(
      id: 'B6040',
      billNumber: 'Bill #6040',
      type: BillType.bill,
      customerName: 'Kathavarayan',
      customerId: '',
      site: 'Nanmangalam',
      billDate: now.subtract(const Duration(days: 14)),
      materials: [
        RentalMaterial(
            name: 'Box', days: 60, dueDate: now.add(const Duration(days: 46))),
        RentalMaterial(
            name: 'Muttu',
            days: 60,
            dueDate: now.add(const Duration(days: 46))),
      ],
    ),
    Bill(
      id: 'DC6049',
      billNumber: 'DC #6049',
      type: BillType.dc,
      customerName: 'Thirupathi',
      customerId: '',
      site: 'Thalambur',
      billDate: now.subtract(const Duration(days: 2)),
      materials: [
        RentalMaterial(
            name: 'Box', days: 45, dueDate: now.add(const Duration(days: 43))),
      ],
    ),
    Bill(
      id: 'DC6044',
      billNumber: 'DC #6044',
      type: BillType.dc,
      customerName: 'Laxmipathi',
      customerId: '',
      site: 'Pallikarani',
      billDate: now.subtract(const Duration(days: 10)),
      materials: [
        RentalMaterial(
            name: 'Shoe', days: 30, dueDate: now.add(const Duration(days: 20))),
      ],
    ),
  ];
}
