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

  RentalMaterial({
    String? id,
    required this.name,
    required this.days,
    required this.dueDate,
    this.status = MaterialStatus.pending,
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

  RentalMaterial copyWith({MaterialStatus? status}) => RentalMaterial(
        id: id,
        name: name,
        days: days,
        dueDate: dueDate,
        status: status ?? this.status,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'days': days,
        'dueDate': dueDate.toIso8601String(),
        'status': status.name,
      };

  factory RentalMaterial.fromJson(Map<String, dynamic> j) => RentalMaterial(
        id: j['id'],
        name: j['name'],
        days: j['days'],
        dueDate: DateTime.parse(j['dueDate']),
        status: MaterialStatus.values.firstWhere((e) => e.name == j['status'],
            orElse: () => MaterialStatus.pending),
      );
}

enum BillStatus { allPending, partial, allReturned, dc }

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
  }) : id = id ?? _uuid.v4();

  BillStatus get status {
    if (type == BillType.dc) {
      final allRet = materials.every((m) => m.isReturned);
      if (allRet) return BillStatus.allReturned;
      return BillStatus.dc;
    }
    final allRet = materials.every((m) => m.isReturned);
    final someRet = materials.any((m) => m.isReturned);
    if (allRet) return BillStatus.allReturned;
    if (someRet) return BillStatus.partial;
    return BillStatus.allPending;
  }

  bool get isClosed => status == BillStatus.allReturned;
  int get returnedCount => materials.where((m) => m.isReturned).length;

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
      materials: [
        RentalMaterial(
            name: 'Box', days: 30, dueDate: now.add(const Duration(days: 30))),
        RentalMaterial(
            name: 'Shoe', days: 15, dueDate: now.add(const Duration(days: 15))),
      ],
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
