import 'package:cloud_firestore/cloud_firestore.dart';

class DeviceHistory {
  final String id;
  final String deviceId;
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime timestamp;
  final int battery;
  final int signalStrength;
  final double temperature;
  final String weatherCondition;

  DeviceHistory({
    required this.id,
    required this.deviceId,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
    required this.battery,
    required this.signalStrength,
    this.temperature = 0.0,
    this.weatherCondition = 'unknown',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'deviceId': deviceId,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'timestamp': Timestamp.fromDate(timestamp),
      'battery': battery,
      'signalStrength': signalStrength,
      'temperature': temperature,
      'weatherCondition': weatherCondition,
    };
  }

  factory DeviceHistory.fromMap(Map<String, dynamic> map) {
    return DeviceHistory(
      id: map['id'] ?? '',
      deviceId: map['deviceId'] ?? '',
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      accuracy: (map['accuracy'] ?? 0.0).toDouble(),
      timestamp: map['timestamp'] is Timestamp
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
      battery: map['battery'] ?? 0,
      signalStrength: map['signalStrength'] ?? 0,
      temperature: (map['temperature'] ?? 0.0).toDouble(),
      weatherCondition: map['weatherCondition'] ?? 'unknown',
    );
  }

  factory DeviceHistory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DeviceHistory.fromMap({...data, 'id': doc.id});
  }
}
