class Customer {
  final String id;
  final String name;
  final String phone;
  final String altPhone;
  final String address;
  final String notes;
  final DateTime createdAt;

  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    this.altPhone = '',
    this.address = '',
    this.notes = '',
    required this.createdAt,
  });

  Customer copyWith({
    String? name,
    String? phone,
    String? altPhone,
    String? address,
    String? notes,
  }) => Customer(
    id: id,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    altPhone: altPhone ?? this.altPhone,
    address: address ?? this.address,
    notes: notes ?? this.notes,
    createdAt: createdAt,
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'phone': phone,
    'altPhone': altPhone,
    'address': address,
    'notes': notes,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  /// Tolerant of missing or wrongly-typed fields so one bad document can
  /// never stop the whole list from loading.
  factory Customer.fromMap(String id, Map<String, dynamic> m) => Customer(
    id: id,
    name: _str(m['name']),
    phone: _str(m['phone']),
    altPhone: _str(m['altPhone']),
    address: _str(m['address']),
    notes: _str(m['notes']),
    createdAt: _millis(m['createdAt']),
  );
}

String _str(Object? v) => v is String ? v : (v?.toString() ?? '');

DateTime _millis(Object? v) => v is int
    ? DateTime.fromMillisecondsSinceEpoch(v)
    : DateTime.fromMillisecondsSinceEpoch(0);

/// Keeps only digits and a leading '+', for comparing phone numbers.
String normalizePhone(String phone) {
  final trimmed = phone.trim();
  final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
  return trimmed.startsWith('+') ? '+$digits' : digits;
}

/// Last 10 digits, so "+91 98400 12345" and "9840012345" match.
String phoneKey(String phone) {
  final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
  return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
}
