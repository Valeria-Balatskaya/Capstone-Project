import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';

class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  String get _userId => _authService.currentUserId ?? 'anonymous';

  Future<void> syncDeviceToCloud(Map<String, dynamic> device) async {
    if (!_authService.isLoggedIn) return;

    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('devices')
          .doc(device['id'])
          .set({
        ...device,
        'lastSynced': FieldValue.serverTimestamp(),
        'userId': _userId,
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error syncing device to cloud: $e');
    }
  }

  Future<void> syncAllDevicesToCloud(List<Map<String, dynamic>> devices) async {
    if (!_authService.isLoggedIn) return;

    try {
      final batch = _firestore.batch();

      for (var device in devices) {
        final docRef = _firestore
            .collection('users')
            .doc(_userId)
            .collection('devices')
            .doc(device['id']);

        batch.set(docRef, {
          ...device,
          'lastSynced': FieldValue.serverTimestamp(),
          'userId': _userId,
        }, SetOptions(merge: true));
      }

      await batch.commit();
    } catch (e) {
      print('Error syncing all devices: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getDevicesFromCloud() async {
    if (!_authService.isLoggedIn) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('devices')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error getting devices from cloud: $e');
      return [];
    }
  }

  Future<void> deleteDeviceFromCloud(String deviceId) async {
    if (!_authService.isLoggedIn) return;

    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('devices')
          .doc(deviceId)
          .delete();
    } catch (e) {
      print('Error deleting device from cloud: $e');
    }
  }

  Stream<List<Map<String, dynamic>>> watchDevices() {
    if (!_authService.isLoggedIn) {
      return Stream.value([]);
    }

    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('devices')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  Future<void> syncSettingsToCloud(Map<String, dynamic> settings) async {
    if (!_authService.isLoggedIn) return;

    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('settings')
          .doc('app_settings')
          .set({
        ...settings,
        'lastSynced': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error syncing settings: $e');
    }
  }

  Future<Map<String, dynamic>?> getSettingsFromCloud() async {
    if (!_authService.isLoggedIn) return null;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('settings')
          .doc('app_settings')
          .get();

      return doc.data();
    } catch (e) {
      print('Error getting settings: $e');
      return null;
    }
  }

  Future<void> syncDeviceHistoryToCloud(String deviceId, List<Map<String, dynamic>> history) async {
    if (!_authService.isLoggedIn) return;

    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('device_history')
          .doc(deviceId)
          .set({
        'history': history,
        'lastSynced': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error syncing history: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getDeviceHistoryFromCloud(String deviceId) async {
    if (!_authService.isLoggedIn) return [];

    try {
      final doc = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('device_history')
          .doc(deviceId)
          .get();

      if (!doc.exists) return [];

      final data = doc.data();
      if (data == null || data['history'] == null) return [];

      return List<Map<String, dynamic>>.from(data['history']);
    } catch (e) {
      print('Error getting history: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getSyncStatus() async {
    if (!_authService.isLoggedIn) {
      return {
        'synced': false,
        'lastSync': null,
        'deviceCount': 0,
      };
    }

    try {
      final devicesSnapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('devices')
          .get();

      DateTime? lastSync;
      if (devicesSnapshot.docs.isNotEmpty) {
        final doc = devicesSnapshot.docs.first;
        final timestamp = doc.data()['lastSynced'] as Timestamp?;
        lastSync = timestamp?.toDate();
      }

      return {
        'synced': true,
        'lastSync': lastSync,
        'deviceCount': devicesSnapshot.docs.length,
      };
    } catch (e) {
      return {
        'synced': false,
        'lastSync': null,
        'deviceCount': 0,
        'error': e.toString(),
      };
    }
  }

  Future<void> deleteAllUserData() async {
    if (!_authService.isLoggedIn) return;

    try {
      final batch = _firestore.batch();

      final devicesSnapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('devices')
          .get();

      for (var doc in devicesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      final settingsDoc = _firestore
          .collection('users')
          .doc(_userId)
          .collection('settings')
          .doc('app_settings');
      batch.delete(settingsDoc);

      await batch.commit();
    } catch (e) {
      print('Error deleting user data: $e');
    }
  }
}