class AppSettings {
  String serverUrl;
  String apiToken;
  String mqttBroker;
  int updateInterval; 
  bool notificationsEnabled;
  
  AppSettings({
    this.serverUrl = '',
    this.apiToken = '',
    this.mqttBroker = '',
    this.updateInterval = 5,
    this.notificationsEnabled = true,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'serverUrl': serverUrl,
      'apiToken': apiToken,
      'mqttBroker': mqttBroker,
      'updateInterval': updateInterval,
      'notificationsEnabled': notificationsEnabled,
    };
  }
  
  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      serverUrl: map['serverUrl'] ?? '',
      apiToken: map['apiToken'] ?? '',
      mqttBroker: map['mqttBroker'] ?? '',
      updateInterval: map['updateInterval'] ?? 5,
      notificationsEnabled: map['notificationsEnabled'] ?? true,
    );
  }
}
