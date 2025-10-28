import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/app_settings.dart';

class SettingsService {
  static const String _settingsKey = 'app_settings';
  
  Future<void> saveSettings(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    final settingsJson = json.encode(settings.toMap());
    await prefs.setString(_settingsKey, settingsJson);
  }
  
  Future<AppSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final settingsJson = prefs.getString(_settingsKey);
    
    if (settingsJson == null) {
      return AppSettings(); 
    }
    
    final settingsMap = json.decode(settingsJson);
    return AppSettings.fromMap(settingsMap);
  }
  
  Future<void> clearSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_settingsKey);
  }
}
