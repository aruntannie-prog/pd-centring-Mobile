import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Per-device reminder preferences.
class ReminderSettings extends ChangeNotifier {
  ReminderSettings._(this._prefs, this._leadDays, this._hour, this._minute);

  static const leadDayOptions = [1, 2, 3, 5, 7];

  static const _kLead = 'reminder_lead_days';
  static const _kHour = 'reminder_hour';
  static const _kMinute = 'reminder_minute';

  final SharedPreferences? _prefs;
  int _leadDays;
  int _hour;
  int _minute;

  static Future<ReminderSettings> load() async {
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint(
        'ReminderSettings: preferences unavailable, using defaults: $e',
      );
    }
    int read(String key, int fallback, bool Function(int) valid) {
      final v = prefs?.getInt(key);
      return v != null && valid(v) ? v : fallback;
    }

    return ReminderSettings._(
      prefs,
      read(_kLead, 3, leadDayOptions.contains),
      read(_kHour, 9, (v) => v >= 0 && v < 24),
      read(_kMinute, 0, (v) => v >= 0 && v < 60),
    );
  }

  /// For tests: nothing is persisted.
  @visibleForTesting
  factory ReminderSettings.inMemory({
    int leadDays = 3,
    int hour = 9,
    int minute = 0,
  }) => ReminderSettings._(null, leadDays, hour, minute);

  /// Days before expiry to send the early reminder. Also the "expiring soon"
  /// window on the Alerts screen.
  int get leadDays => _leadDays;
  int get hour => _hour;
  int get minute => _minute;

  Future<void> setLeadDays(int days) async {
    if (!leadDayOptions.contains(days) || days == _leadDays) return;
    _leadDays = days;
    notifyListeners();
    await _prefs?.setInt(_kLead, days);
  }

  Future<void> setReminderTime(int hour, int minute) async {
    if (hour == _hour && minute == _minute) return;
    _hour = hour;
    _minute = minute;
    notifyListeners();
    await _prefs?.setInt(_kHour, hour);
    await _prefs?.setInt(_kMinute, minute);
  }
}
