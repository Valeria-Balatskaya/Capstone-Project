import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class DeviceService {
  static const String _devicesKey = 'tracked_devices';
  
  Future<void> saveDevices(List<Map<String, dynamic>> devices) async {
    final prefs = await SharedPreferences.getInstance();
    final devicesJson = json.encode(devices);
    await prefs.setString(_devicesKey, devicesJson);
  }
  
  Future<List<Map<String, dynamic>>> loadDevices() async {
    final prefs = await SharedPreferences.getInstance();
    final devicesJson = prefs.getString(_devicesKey);
    
    if (devicesJson == null) {
      return [
        {
          'id': 'Device-001',
          'name': 'Tracking Tag 1',
          'status': 'online',
          'lastSeen': '2 min ago',
          'battery': 87,
          'accuracy': 5.2,
        },
        {
          'id': 'Device-002',
          'name': 'Tracking Tag 2',
          'status': 'online',
          'lastSeen': '5 min ago',
          'battery': 65,
          'accuracy': 8.1,
        },
        {
          'id': 'Device-003',
          'name': 'Tracking Tag 3',
          'status': 'offline',
          'lastSeen': '1 hour ago',
          'battery': 23,
          'accuracy': 0.0,
        },
      ];
    }
    
    final List<dynamic> devicesList = json.decode(devicesJson);
    return devicesList.map((device) => Map<String, dynamic>.from(device)).toList();
  }
  
  Future<void> clearDevices() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_devicesKey);
  }
}
