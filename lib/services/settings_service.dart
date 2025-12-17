import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/app_settings.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  static const String _settingsKey = 'app_settings';
  AppSettings? _cachedSettings;

  Future<void> saveSettings(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    final settingsJson = json.encode(settings.toMap());
    await prefs.setString(_settingsKey, settingsJson);
    _cachedSettings = settings;
  }

  Future<AppSettings> loadSettings() async {
    if (_cachedSettings != null) {
      return _cachedSettings!;
    }

    final prefs = await SharedPreferences.getInstance();
    final settingsJson = prefs.getString(_settingsKey);

    if (settingsJson == null) {
      _cachedSettings = AppSettings();
      return _cachedSettings!;
    }

    final settingsMap = json.decode(settingsJson);
    _cachedSettings = AppSettings.fromMap(settingsMap);
    return _cachedSettings!;
  }

  Future<void> clearSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_settingsKey);
    _cachedSettings = null;
  }

  Future<void> updateSetting(String key, dynamic value) async {
    final settings = await loadSettings();
    final map = settings.toMap();
    map[key] = value;
    await saveSettings(AppSettings.fromMap(map));
  }

  void clearCache() {
    _cachedSettings = null;
  }
}
