import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps half-typed forms on the device.
///
/// On Android the system may close the app while the camera is open (common
/// on phones with little memory). Without this, everything typed into the
/// new customer form would be lost when the app comes back.
class DraftStore {
  DraftStore._(this._prefs);

  final SharedPreferences? _prefs;
  final _memory = <String, String>{};

  static const _prefix = 'draft_';

  static Future<DraftStore> load() async {
    try {
      return DraftStore._(await SharedPreferences.getInstance());
    } catch (e) {
      debugPrint('DraftStore: preferences unavailable, drafts kept in memory');
      return DraftStore._(null);
    }
  }

  /// Nothing is persisted; used in tests and demo mode.
  factory DraftStore.inMemory() => DraftStore._(null);

  Map<String, String>? read(String key) {
    final raw = _prefs?.getString('$_prefix$key') ?? _memory[key];
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return {
        for (final e in decoded.entries)
          if (e.value is String) '${e.key}': e.value as String,
      };
    } catch (_) {
      return null;
    }
  }

  void write(String key, Map<String, String> values) {
    final raw = jsonEncode(values);
    _memory[key] = raw;
    _prefs?.setString('$_prefix$key', raw);
  }

  void clear(String key) {
    _memory.remove(key);
    _prefs?.remove('$_prefix$key');
  }
}
