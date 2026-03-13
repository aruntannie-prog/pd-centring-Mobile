import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class Customer {
  final String id;
  final String name;
  final String phone;
  final String secondaryPhone;
  final String address;
  final String site;
  final String gstNumber;
  final String referBy;
  final int billCount;
  final bool isActive;
  final String profilePhotoUrl;
  final String addressProofUrl;

  /// Universally converts any Google Drive link (including legacy dual || strings,
  /// share links, or thumbnails) into a permanent direct-access public URL.
  static String normalizeDriveUrl(String? url) {
    if (url == null || url.trim().isEmpty) return '';
    // Base64 data URLs should be returned as-is — never touch them
    if (url.startsWith('data:')) return url;
    // Strip legacy 'thumb||full' combined payload
    String cleanUrl = url.contains('||') ? url.split('||').last : url.trim();

    // Extract ID using RegExp for any Google Drive URL format
    if (cleanUrl.contains('drive.google.com') ||
        cleanUrl.contains('docs.google.com')) {
      final RegExp idRegExp = RegExp(r'[-\w]{25,}');
      final match = idRegExp.firstMatch(cleanUrl);
      if (match != null) {
        final id = match.group(0);
        final normalized = 'https://drive.google.com/uc?export=view&id=$id';
        print('Customer Data: Normalized URL [$cleanUrl] -> [$normalized]');
        return normalized;
      }
    }

    print('Customer Data: Keeping non-Drive URL [$cleanUrl]');
    return cleanUrl;
  }

  Customer({
    String? id,
    required this.name,
    required this.phone,
    this.secondaryPhone = '',
    this.address = '',
    this.site = '',
    this.gstNumber = '',
    this.referBy = '',
    this.billCount = 0,
    this.isActive = true,
    this.profilePhotoUrl = '',
    this.addressProofUrl = '',
  }) : id = id ?? _uuid.v4();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'secondaryPhone': secondaryPhone,
        'address': address,
        'site': site,
        'gstNumber': gstNumber,
        'referBy': referBy,
        'billCount': billCount,
        'isActive': isActive,
        'profilePhotoUrl': profilePhotoUrl,
        'addressProofUrl': addressProofUrl,
      };

  factory Customer.fromJson(Map<String, dynamic> j) => Customer(
        id: j['id'],
        name: j['name'],
        phone: j['phone'],
        secondaryPhone: j['secondaryPhone'] ?? '',
        address: j['address'] ?? '',
        site: j['site'] ?? '',
        gstNumber: j['gstNumber'] ?? '',
        referBy: j['referBy'] ?? '',
        billCount: int.tryParse(j['billCount']?.toString() ?? '0') ?? 0,
        isActive: j['isActive']?.toString().toLowerCase() == 'true',
        profilePhotoUrl: normalizeDriveUrl(j['profilePhotoUrl']),
        addressProofUrl: normalizeDriveUrl(j['addressProofUrl']),
      );
  Customer copyWith({
    String? id,
    String? name,
    String? phone,
    String? secondaryPhone,
    String? address,
    String? site,
    String? gstNumber,
    String? referBy,
    int? billCount,
    bool? isActive,
    String? profilePhotoUrl,
    String? addressProofUrl,
  }) =>
      Customer(
        id: id ?? this.id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        secondaryPhone: secondaryPhone ?? this.secondaryPhone,
        address: address ?? this.address,
        site: site ?? this.site,
        gstNumber: gstNumber ?? this.gstNumber,
        referBy: referBy ?? this.referBy,
        billCount: billCount ?? this.billCount,
        isActive: isActive ?? this.isActive,
        profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
        addressProofUrl: addressProofUrl ?? this.addressProofUrl,
      );
}
