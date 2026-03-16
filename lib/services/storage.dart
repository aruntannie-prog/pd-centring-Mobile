import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static Future<void> saveCache(String key, String value) async {
    await _prefs?.setString('cache_$key', value);
  }

  static String? getCache(String key) {
    return _prefs?.getString('cache_$key');
  }

  static Future<void> clearCache() async {
    final keys = _prefs?.getKeys() ?? {};
    for (String key in keys) {
      if (key.startsWith('cache_')) {
        await _prefs?.remove(key);
      }
    }
  }

  static Future<void> setPreference(String key, String value) async {
    await _prefs?.setString('pref_$key', value);
  }

  static String? getPreference(String key) {
    return _prefs?.getString('pref_$key');
  }
}
