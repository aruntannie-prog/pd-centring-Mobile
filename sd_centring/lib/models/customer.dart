/// Kinds of ID / address proof staff usually collect.
const List<String> documentKinds = [
  'Aadhaar',
  'PAN',
  'Voter ID',
  'Driving licence',
  'Utility bill',
  'Other',
];

/// An uploaded ID or address-proof file. The file itself lives in storage;
/// only this small record is kept on the customer.
class CustomerDoc {
  final String id;
  final String kind;
  final String fileName;
  final String url;
  final String contentType;
  final int sizeBytes;
  final DateTime uploadedAt;

  const CustomerDoc({
    required this.id,
    required this.kind,
    required this.fileName,
    required this.url,
    required this.contentType,
    required this.sizeBytes,
    required this.uploadedAt,
  });

  bool get isPdf => contentType == 'application/pdf';
  bool get isImage => contentType.startsWith('image/');

  Map<String, dynamic> toMap() => {
    'id': id,
    'kind': kind,
    'fileName': fileName,
    'url': url,
    'contentType': contentType,
    'sizeBytes': sizeBytes,
    'uploadedAt': uploadedAt.millisecondsSinceEpoch,
  };

  static CustomerDoc? tryFromMap(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final url = raw['url'];
    if (id is! String || url is! String || url.isEmpty) return null;
    return CustomerDoc(
      id: id,
      kind: _str(raw['kind']).isEmpty ? 'Other' : _str(raw['kind']),
      fileName: _str(raw['fileName']),
      url: url,
      contentType: _str(raw['contentType']),
      sizeBytes: raw['sizeBytes'] is int ? raw['sizeBytes'] as int : 0,
      uploadedAt: _millis(raw['uploadedAt']),
    );
  }
}

class Customer {
  final String id;
  final String name;
  final String phone;
  final String altPhone;
  final String address;
  final String notes;

  /// Storage URL of the profile photo, or empty.
  final String photoUrl;
  final List<CustomerDoc> documents;
  final DateTime createdAt;

  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    this.altPhone = '',
    this.address = '',
    this.notes = '',
    this.photoUrl = '',
    this.documents = const [],
    required this.createdAt,
  });

  Customer copyWith({
    String? name,
    String? phone,
    String? altPhone,
    String? address,
    String? notes,
    String? photoUrl,
    List<CustomerDoc>? documents,
  }) => Customer(
    id: id,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    altPhone: altPhone ?? this.altPhone,
    address: address ?? this.address,
    notes: notes ?? this.notes,
    photoUrl: photoUrl ?? this.photoUrl,
    documents: documents ?? this.documents,
    createdAt: createdAt,
  );

  /// Images and documents are stored as URLs to files in storage, never
  /// embedded in the record (Firestore documents are limited to 1 MB).
  Map<String, dynamic> toMap() => {
    'name': name,
    'phone': phone,
    'altPhone': altPhone,
    'address': address,
    'notes': notes,
    'photoUrl': photoUrl,
    'documents': documents.map((d) => d.toMap()).toList(),
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
    photoUrl: _str(m['photoUrl']),
    documents: m['documents'] is List
        ? (m['documents'] as List)
              .map(CustomerDoc.tryFromMap)
              .whereType<CustomerDoc>()
              .toList()
        : const [],
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
