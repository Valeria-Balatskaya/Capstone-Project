import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/settings_service.dart';

class DeviceService {
  static const String _devicesKey = 'tracked_devices';
  final _settingsService = SettingsService();

  Future<List<Map<String, dynamic>>> fetchDevicesFromChirpStack() async {
    try {
      final settings = await _settingsService.loadSettings();

      final appsResponse = await http
          .get(
            Uri.parse('${settings.serverUrl}/api/applications?limit=100'),
            headers: {
              'Accept': 'application/json',
              'Grpc-Metadata-Authorization': 'Bearer ${settings.apiToken}',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (appsResponse.statusCode != 200) {
        throw Exception('Failed to fetch applications');
      }

      final appsData = json.decode(appsResponse.body);
      List<Map<String, dynamic>> allDevices = [];

      if (appsData['result'] != null) {
        for (var app in appsData['result']) {
          final appId = app['id'];

          final devicesResponse = await http
              .get(
                Uri.parse(
                  '${settings.serverUrl}/api/applications/$appId/devices?limit=100',
                ),
                headers: {
                  'Accept': 'application/json',
                  'Grpc-Metadata-Authorization': 'Bearer ${settings.apiToken}',
                },
              )
              .timeout(const Duration(seconds: 10));

          if (devicesResponse.statusCode == 200) {
            final devicesData = json.decode(devicesResponse.body);

            if (devicesData['result'] != null) {
              for (var device in devicesData['result']) {
                allDevices.add({
                  'id': device['devEui'] ?? device['name'] ?? 'unknown',
                  'name': device['name'] ?? 'Unnamed Device',
                  'description': device['description'] ?? '',
                  'applicationId': appId,
                  'applicationName': app['name'] ?? '',
                  'deviceProfileId': device['deviceProfileId'] ?? '',
                  'status': 'unknown',
                  'lastSeen': 'Never',
                  'battery': 0,
                  'accuracy': 0.0,
                });
              }
            }
          }
        }
      }

      return allDevices;
    } catch (e) {
      print('Error fetching devices from ChirpStack: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getDeviceLocation(String devEui) async {
    try {
      final settings = await _settingsService.loadSettings();

      final response = await http
          .get(
            Uri.parse(
              '${settings.serverUrl}/api/devices/$devEui/events?limit=1&types=up',
            ),
            headers: {
              'Accept': 'application/json',
              'Grpc-Metadata-Authorization': 'Bearer ${settings.apiToken}',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['result'] != null && data['result'].isNotEmpty) {
          final event = data['result'][0];

          if (event['data'] != null) {
            final eventData = event['data'];
            return {
              'latitude': eventData['latitude'] ?? 0.0,
              'longitude': eventData['longitude'] ?? 0.0,
              'altitude': eventData['altitude'] ?? 0.0,
              'accuracy': eventData['accuracy'] ?? 0.0,
              'timestamp':
                  event['publishedAt'] ?? DateTime.now().toIso8601String(),
            };
          }
        }
      }
      return null;
    } catch (e) {
      print('Error fetching device location: $e');
      return null;
    }
  }

  Future<void> saveDevices(List<Map<String, dynamic>> devices) async {
    final prefs = await SharedPreferences.getInstance();
    final devicesJson = json.encode(devices);
    await prefs.setString(_devicesKey, devicesJson);
  }

  Future<List<Map<String, dynamic>>> loadDevices() async {
    final chirpStackDevices = await fetchDevicesFromChirpStack();

    if (chirpStackDevices.isNotEmpty) {
      await saveDevices(chirpStackDevices);
      return chirpStackDevices;
    }

    final prefs = await SharedPreferences.getInstance();
    final devicesJson = prefs.getString(_devicesKey);

    if (devicesJson != null) {
      final List devicesList = json.decode(devicesJson);
      return devicesList.map((e) => Map<String, dynamic>.from(e)).toList();
    }

    return [
      {
        'id': 'Device-001',
        'name': 'Tracking Tag 1',
        'status': 'offline',
        'lastSeen': 'Not connected',
        'battery': 0,
        'accuracy': 0.0,
      },
      {
        'id': 'Device-002',
        'name': 'Tracking Tag 2',
        'status': 'offline',
        'lastSeen': 'Not connected',
        'battery': 0,
        'accuracy': 0.0,
      },
    ];
  }

  Future<void> addDevice(Map<String, dynamic> device) async {
    final devices = await loadDevices();
    devices.add(device);
    await saveDevices(devices);
  }

  Future<void> removeDevice(String deviceId) async {
    final devices = await loadDevices();
    devices.removeWhere((device) => device['id'] == deviceId);
    await saveDevices(devices);
  }

  Future<void> updateDevice(
    String deviceId,
    Map<String, dynamic> updates,
  ) async {
    final devices = await loadDevices();
    final index = devices.indexWhere((device) => device['id'] == deviceId);
    if (index != -1) {
      devices[index] = {...devices[index], ...updates};
      await saveDevices(devices);
    }
  }
}
