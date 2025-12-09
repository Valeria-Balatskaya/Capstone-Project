class DeviceHistory {
  final String deviceId;
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime timestamp;
  final int battery;
  final int signalStrength;

  DeviceHistory({
    required this.deviceId,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
    required this.battery,
    required this.signalStrength,
  });

  Map<String, dynamic> toMap() {
    return {
      'deviceId': deviceId,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'timestamp': timestamp.toIso8601String(),
      'battery': battery,
      'signalStrength': signalStrength,
    };
  }

  factory DeviceHistory.fromMap(Map<String, dynamic> map) {
    return DeviceHistory(
      deviceId: map['deviceId'] ?? '',
      latitude: map['latitude']?.toDouble() ?? 0.0,
      longitude: map['longitude']?.toDouble() ?? 0.0,
      accuracy: map['accuracy']?.toDouble() ?? 0.0,
      timestamp: DateTime.parse(map['timestamp']),
      battery: map['battery'] ?? 0,
      signalStrength: map['signalStrength'] ?? 0,
    );
  }
}