import '../config/brand.dart';
import '../core/dates.dart';
import '../core/quantity.dart';
import '../models/rental.dart';
import 'expiry.dart';

/// Turns a stored phone number into the digits WhatsApp expects
/// (country code + number, no '+', spaces or leading 0).
///
/// Returns null when the number can't be a valid mobile number, so the UI
/// can explain instead of opening WhatsApp on a wrong chat.
String? whatsAppNumber(
  String phone, {
  String countryCode = Brand.whatsAppCountryCode,
}) {
  final trimmed = phone.trim();
  var digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return null;
  if (trimmed.startsWith('+')) {
    return digits.length >= 10 && digits.length <= 15 ? digits : null;
  }
  if (digits.startsWith('00')) digits = digits.substring(2);
  // Local formats: 98400 12345, 098400 12345.
  if (digits.length == 11 && digits.startsWith('0')) {
    digits = digits.substring(1);
  }
  if (digits.length == 10) return '$countryCode$digits';
  if (digits.length == 10 + countryCode.length &&
      digits.startsWith(countryCode)) {
    return digits;
  }
  return null;
}

/// Click-to-chat link: opens WhatsApp with [message] typed in, ready to send.
/// This is WhatsApp's official, free mechanism; nothing is sent without the
/// user tapping Send.
///
/// Encoded by hand: `Uri.https` would turn spaces into '+', which WhatsApp
/// can show literally. encodeComponent uses %20.
Uri whatsAppLink(String number, String message) =>
    Uri.parse('https://wa.me/$number?text=${Uri.encodeComponent(message)}');

/// Reminder text for a delivery. No prices — just what is out and by when.
String expiryMessage(
  Rental r, {
  required String customerName,
  required ExpiryInfo info,
}) {
  final items = r.outstandingItems
      .map((i) => '• ${i.name}: ${formatQty(r.outstandingQty(i))} ${i.unit}')
      .join('\n');
  final where = r.site.isEmpty ? '' : ' at ${r.site}';
  final date = formatDay(r.expiresOn);

  final status = switch (info.status) {
    ExpiryStatus.expired =>
      'The rental period for DC ${r.dcNumber}$where ended on $date '
          '(${info.label}).',
    ExpiryStatus.dueToday =>
      'The rental period for DC ${r.dcNumber}$where ends today ($date).',
    _ =>
      'The rental period for DC ${r.dcNumber}$where ends on $date (${info.label}).',
  };

  final sign = [
    Brand.appName,
    if (Brand.phone.isNotEmpty) Brand.phone,
  ].join(' · ');

  return [
    'Hello $customerName,',
    '',
    status,
    if (items.isNotEmpty) ...['', 'Material still with you:', items],
    '',
    'Please arrange the return, or reply to extend the rental.',
    '',
    'Thank you,',
    sign,
  ].join('\n');
}
