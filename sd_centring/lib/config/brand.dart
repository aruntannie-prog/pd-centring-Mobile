/// Business details for SD Centring.
///
/// Everything customer-specific lives here so it can be filled in later
/// without touching the rest of the app.
class Brand {
  Brand._();

  static const appName = 'SD Centring';
  static const tagline = 'Rental expiry tracker';

  /// Prefix and first number for delivery challan (DC) numbers.
  static const dcPrefix = 'SD-';
  static const dcStartNumber = 1001;

  /// Added to 10-digit numbers for WhatsApp links (91 = India).
  static const whatsAppCountryCode = '91';

  /// Time zone used to schedule reminder notifications.
  static const timeZone = 'Asia/Kolkata';

  // To be provided by SD Centring.
  static const ownerName = '';
  static const phone = '';
  static const address = '';
}

/// Material names offered as quick picks when adding items to a delivery.
/// Users can always type any other name.
const List<String> defaultMaterials = [
  'Column Box',
  'Round Box',
  'Side Sheet',
  'Palagai',
  'Muttu',
  'Props',
  'Span',
  'Roof Sheet',
  'Adjustment Sheet',
  'Shoe',
];

const List<String> defaultUnits = ['pcs', 'ft', 'nos', 'sets'];
