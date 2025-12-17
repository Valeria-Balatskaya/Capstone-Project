class AppSettings {
  final String serverUrl;
  final String apiToken;
  final String mqttBroker;
  final int updateInterval;
  final bool notificationsEnabled;
  final bool lowBatteryAlerts;
  final bool accuracyWarnings;
  final bool movementDetection;
  final int lowBatteryThreshold;
  final double accuracyThreshold;

  AppSettings({
    this.serverUrl = '',
    this.apiToken = '',
    this.mqttBroker = '',
    this.updateInterval = 5,
    this.notificationsEnabled = true,
    this.lowBatteryAlerts = true,
    this.accuracyWarnings = true,
    this.movementDetection = true,
    this.lowBatteryThreshold = 20,
    this.accuracyThreshold = 10.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'serverUrl': serverUrl,
      'apiToken': apiToken,
      'mqttBroker': mqttBroker,
      'updateInterval': updateInterval,
      'notificationsEnabled': notificationsEnabled,
      'lowBatteryAlerts': lowBatteryAlerts,
      'accuracyWarnings': accuracyWarnings,
      'movementDetection': movementDetection,
      'lowBatteryThreshold': lowBatteryThreshold,
      'accuracyThreshold': accuracyThreshold,
    };
  }

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      serverUrl: map['serverUrl'] ?? '',
      apiToken: map['apiToken'] ?? '',
      mqttBroker: map['mqttBroker'] ?? '',
      updateInterval: map['updateInterval'] ?? 5,
      notificationsEnabled: map['notificationsEnabled'] ?? true,
      lowBatteryAlerts: map['lowBatteryAlerts'] ?? true,
      accuracyWarnings: map['accuracyWarnings'] ?? true,
      movementDetection: map['movementDetection'] ?? true,
      lowBatteryThreshold: map['lowBatteryThreshold'] ?? 20,
      accuracyThreshold: (map['accuracyThreshold'] ?? 10.0).toDouble(),
    );
  }

  AppSettings copyWith({
    String? serverUrl,
    String? apiToken,
    String? mqttBroker,
    int? updateInterval,
    bool? notificationsEnabled,
    bool? lowBatteryAlerts,
    bool? accuracyWarnings,
    bool? movementDetection,
    int? lowBatteryThreshold,
    double? accuracyThreshold,
  }) {
    return AppSettings(
      serverUrl: serverUrl ?? this.serverUrl,
      apiToken: apiToken ?? this.apiToken,
      mqttBroker: mqttBroker ?? this.mqttBroker,
      updateInterval: updateInterval ?? this.updateInterval,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      lowBatteryAlerts: lowBatteryAlerts ?? this.lowBatteryAlerts,
      accuracyWarnings: accuracyWarnings ?? this.accuracyWarnings,
      movementDetection: movementDetection ?? this.movementDetection,
      lowBatteryThreshold: lowBatteryThreshold ?? this.lowBatteryThreshold,
      accuracyThreshold: accuracyThreshold ?? this.accuracyThreshold,
    );
  }
}
