import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/device.dart';
import '../models/device_history.dart';
import 'auth_service.dart';
import 'simulation_service.dart';

class DeviceService {
  static final DeviceService _instance = DeviceService._internal();
  factory DeviceService() => _instance;
  DeviceService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  final SimulationService _simulationService = SimulationService();

  CollectionReference get _devicesCollection {
    final userId = _authService.currentUserId;
    if (userId == null) throw Exception('User not logged in');
    return _firestore.collection('users').doc(userId).collection('devices');
  }

  CollectionReference _historyCollection(String deviceId) {
    final userId = _authService.currentUserId;
    if (userId == null) throw Exception('User not logged in');
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('devices')
        .doc(deviceId)
        .collection('history');
  }

  Stream<List<Device>> watchDevices() {
    if (!_authService.isLoggedIn) {
      return Stream.value([]);
    }

    return _devicesCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Device.fromFirestore(doc)).toList();
    });
  }

  Future<List<Device>> getDevices() async {
    if (!_authService.isLoggedIn) return [];

    try {
      final snapshot =
          await _devicesCollection.orderBy('createdAt', descending: true).get();
      return snapshot.docs.map((doc) => Device.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting devices: $e');
      return [];
    }
  }

  Future<Device?> getDevice(String deviceId) async {
    if (!_authService.isLoggedIn) return null;

    try {
      final doc = await _devicesCollection.doc(deviceId).get();
      if (!doc.exists) return null;
      return Device.fromFirestore(doc);
    } catch (e) {
      print('Error getting device: $e');
      return null;
    }
  }

  Future<Device?> createDevice({
    required String name,
    String description = '',
    double? latitude,
    double? longitude,
  }) async {
    if (!_authService.isLoggedIn) return null;

    try {
      final deviceId = _devicesCollection.doc().id;
      final now = DateTime.now();
      
      double baseLatitude;
      double baseLongitude;
      
      if (latitude != null && longitude != null) {
        baseLatitude = latitude;
        baseLongitude = longitude;
      } else {
        final diverseLocation = _simulationService.generateDiverseLocation(deviceId);
        baseLatitude = diverseLocation['latitude']!;
        baseLongitude = diverseLocation['longitude']!;
      }

      final simulatedData = _simulationService.generateInitialDeviceData(
        deviceId: deviceId,
        baseLatitude: baseLatitude,
        baseLongitude: baseLongitude,
      );

      final device = Device(
        id: deviceId,
        name: name,
        description: description,
        status: 'online',
        lastSeen: now,
        battery: simulatedData['battery'],
        accuracy: simulatedData['accuracy'],
        latitude: simulatedData['latitude'],
        longitude: simulatedData['longitude'],
        signalStrength: simulatedData['signalStrength'],
        createdAt: now,
        userId: _authService.currentUserId!,
      );

      await _devicesCollection.doc(deviceId).set(device.toMap());

      await _generateInitialHistory(device);

      return device;
    } catch (e) {
      print('Error creating device: $e');
      return null;
    }
  }

  Future<void> _generateInitialHistory(Device device) async {
    final historyEntries =
        _simulationService.generateHistoricalData(device, days: 14);

    final batch = _firestore.batch();
    for (var entry in historyEntries) {
      final docRef = _historyCollection(device.id).doc(entry.id);
      batch.set(docRef, entry.toMap());
    }
    await batch.commit();
  }

  Future<bool> updateDevice(Device device) async {
    if (!_authService.isLoggedIn) return false;

    try {
      await _devicesCollection.doc(device.id).update(device.toMap());
      return true;
    } catch (e) {
      print('Error updating device: $e');
      return false;
    }
  }

  Future<bool> deleteDevice(String deviceId) async {
    if (!_authService.isLoggedIn) return false;

    try {
      final historySnapshot = await _historyCollection(deviceId).get();
      final batch = _firestore.batch();
      for (var doc in historySnapshot.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(_devicesCollection.doc(deviceId));
      await batch.commit();

      return true;
    } catch (e) {
      print('Error deleting device: $e');
      return false;
    }
  }

  Future<void> updateDeviceData(String deviceId) async {
    if (!_authService.isLoggedIn) return;

    try {
      final device = await getDevice(deviceId);
      if (device == null) return;

      final newData = _simulationService.generateUpdatedDeviceData(device);
      final now = DateTime.now();

      await _devicesCollection.doc(deviceId).update({
        'battery': newData['battery'],
        'accuracy': newData['accuracy'],
        'latitude': newData['latitude'],
        'longitude': newData['longitude'],
        'signalStrength': newData['signalStrength'],
        'lastSeen': Timestamp.fromDate(now),
        'status': newData['battery'] > 5 ? 'online' : 'offline',
      });

      final historyEntry = DeviceHistory(
        id: _historyCollection(deviceId).doc().id,
        deviceId: deviceId,
        latitude: newData['latitude'],
        longitude: newData['longitude'],
        accuracy: newData['accuracy'],
        timestamp: now,
        battery: newData['battery'],
        signalStrength: newData['signalStrength'],
      );

      await _historyCollection(deviceId).doc(historyEntry.id).set(historyEntry.toMap());
    } catch (e) {
      print('Error updating device data: $e');
    }
  }

  Stream<List<DeviceHistory>> watchDeviceHistory(String deviceId, {int limit = 100}) {
    if (!_authService.isLoggedIn) {
      return Stream.value([]);
    }

    return _historyCollection(deviceId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => DeviceHistory.fromFirestore(doc)).toList();
    });
  }

  Future<List<DeviceHistory>> getDeviceHistory(
    String deviceId, {
    int limit = 100,
    DateTime? since,
  }) async {
    if (!_authService.isLoggedIn) return [];

    try {
      var query = _historyCollection(deviceId)
          .orderBy('timestamp', descending: true)
          .limit(limit);

      if (since != null) {
        query = query.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(since));
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => DeviceHistory.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting device history: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getDeviceStatistics(
    String deviceId, {
    DateTime? since,
  }) async {
    final history = await getDeviceHistory(deviceId, limit: 200, since: since);

    if (history.isEmpty) {
      return {
        'averageAccuracy': 0.0,
        'bestAccuracy': 0.0,
        'worstAccuracy': 0.0,
        'averageBattery': 0,
        'averageSignal': 0,
        'totalDataPoints': 0,
        'uptimePercent': 0.0,
      };
    }

    final accuracies = history.map((h) => h.accuracy).toList();
    final batteries = history.map((h) => h.battery).toList();
    final signals = history.map((h) => h.signalStrength).toList();

    return {
      'averageAccuracy':
          accuracies.reduce((a, b) => a + b) / accuracies.length,
      'bestAccuracy': accuracies.reduce((a, b) => a < b ? a : b),
      'worstAccuracy': accuracies.reduce((a, b) => a > b ? a : b),
      'averageBattery':
          (batteries.reduce((a, b) => a + b) / batteries.length).round(),
      'averageSignal':
          (signals.reduce((a, b) => a + b) / signals.length).round(),
      'totalDataPoints': history.length,
      'uptimePercent': _calculateUptime(history),
    };
  }

  double _calculateUptime(List<DeviceHistory> history) {
    if (history.length < 2) return 100.0;
    
    int goodReadings = history.where((h) => h.signalStrength > 30).length;
    return (goodReadings / history.length) * 100;
  }

  Future<void> clearAllDeviceHistory(String deviceId) async {
    if (!_authService.isLoggedIn) return;

    try {
      final snapshot = await _historyCollection(deviceId).get();
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      print('Error clearing history: $e');
    }
  }
}
