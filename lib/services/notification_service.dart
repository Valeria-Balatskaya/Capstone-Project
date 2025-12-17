import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/device.dart';

class NotificationPreferences {
  final bool lowBatteryAlerts;
  final bool accuracyWarnings;
  final bool movementDetection;
  final bool dailySummary;

  NotificationPreferences({
    this.lowBatteryAlerts = true,
    this.accuracyWarnings = true,
    this.movementDetection = true,
    this.dailySummary = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'lowBatteryAlerts': lowBatteryAlerts,
      'accuracyWarnings': accuracyWarnings,
      'movementDetection': movementDetection,
      'dailySummary': dailySummary,
    };
  }

  factory NotificationPreferences.fromMap(Map<String, dynamic> map) {
    return NotificationPreferences(
      lowBatteryAlerts: map['lowBatteryAlerts'] ?? true,
      accuracyWarnings: map['accuracyWarnings'] ?? true,
      movementDetection: map['movementDetection'] ?? true,
      dailySummary: map['dailySummary'] ?? true,
    );
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _permissionGranted = false;

  static const String _preferencesKey = 'notification_preferences';

  bool get isInitialized => _initialized;
  bool get hasPermission => _permissionGranted;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _initialized = true;
  }

  Future<bool> requestPermissions() async {
    final androidImplementation =
        _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      final granted = await androidImplementation.requestNotificationsPermission();
      _permissionGranted = granted ?? false;
      return _permissionGranted;
    }

    final iosImplementation = _notifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();

    if (iosImplementation != null) {
      final granted = await iosImplementation.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      _permissionGranted = granted ?? false;
      return _permissionGranted;
    }

    _permissionGranted = true;
    return true;
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
  }

  Future<NotificationPreferences> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final prefsJson = prefs.getString(_preferencesKey);
    
    if (prefsJson == null) {
      return NotificationPreferences();
    }
    
    try {
      final map = json.decode(prefsJson) as Map<String, dynamic>;
      return NotificationPreferences.fromMap(map);
    } catch (e) {
      return NotificationPreferences();
    }
  }

  Future<void> savePreferences(NotificationPreferences preferences) async {
    final prefs = await SharedPreferences.getInstance();
    final prefsJson = json.encode(preferences.toMap());
    await prefs.setString(_preferencesKey, prefsJson);
  }

  Future<void> showSmartSuggestion(String title, String message) async {
    if (!_permissionGranted) {
      await requestPermissions();
    }

    const androidDetails = AndroidNotificationDetails(
      'smart_suggestions_channel',
      'Smart Suggestions',
      channelDescription: 'AI-powered smart suggestions and alerts',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF9C27B0),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      title,
      message,
      details,
      payload: 'smart_suggestion',
    );
  }

  Future<void> showLowBatteryNotification(Device device) async {
    if (!_permissionGranted) return;

    const androidDetails = AndroidNotificationDetails(
      'low_battery_channel',
      'Low Battery Alerts',
      channelDescription: 'Alerts when device battery is low',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFFF44336),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      device.id.hashCode,
      'Low Battery Alert',
      '${device.name} battery at ${device.battery}%. Charge soon.',
      details,
      payload: 'battery_${device.id}',
    );
  }

  Future<void> showSignalWarningNotification(Device device) async {
    if (!_permissionGranted) return;

    const androidDetails = AndroidNotificationDetails(
      'signal_channel',
      'Signal Warnings',
      channelDescription: 'Warnings when signal quality is poor',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFFFF9800),
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _notifications.show(
      device.id.hashCode + 1000,
      'Poor Signal Quality',
      '${device.name} signal at ${device.signalStrength}%. Check gateway connection.',
      details,
      payload: 'signal_${device.id}',
    );
  }

  Future<void> showAccuracyWarningNotification(Device device) async {
    if (!_permissionGranted) return;

    const androidDetails = AndroidNotificationDetails(
      'accuracy_channel',
      'Accuracy Warnings',
      channelDescription: 'Warnings when positioning accuracy is poor',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFFFF9800),
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _notifications.show(
      device.id.hashCode + 2000,
      'Poor Accuracy Detected',
      '${device.name} accuracy: ${device.accuracy.toStringAsFixed(1)}m.',
      details,
      payload: 'accuracy_${device.id}',
    );
  }

  Future<void> showDeviceOfflineNotification(Device device) async {
    if (!_permissionGranted) return;

    const androidDetails = AndroidNotificationDetails(
      'offline_channel',
      'Device Status',
      channelDescription: 'Notifications when device goes offline',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF9E9E9E),
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(presentAlert: true),
    );

    await _notifications.show(
      device.id.hashCode + 3000,
      'Device Offline',
      '${device.name} appears to be offline.',
      details,
      payload: 'offline_${device.id}',
    );
  }

  Future<void> showAIInsightNotification(String title, String message) async {
    if (!_permissionGranted) return;

    const androidDetails = AndroidNotificationDetails(
      'ai_insights_channel',
      'AI Insights',
      channelDescription: 'Smart insights from AI analysis',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF9C27B0),
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      title,
      message,
      details,
      payload: 'ai_insight',
    );
  }

  Future<void> showWelcomeNotification(String userName) async {
    if (!_permissionGranted) return;

    const androidDetails = AndroidNotificationDetails(
      'welcome_channel',
      'Welcome',
      channelDescription: 'Welcome notifications',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF2196F3),
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _notifications.show(
      0,
      'Welcome to LoraTrack!',
      'Hello $userName! Start by adding your first device.',
      details,
      payload: 'welcome',
    );
  }

  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  Future<void> checkAndNotifyDeviceIssues(Device device) async {
    if (!_permissionGranted) return;

    if (device.battery < 20) {
      await showLowBatteryNotification(device);
    }

    if (device.signalStrength < 40) {
      await showSignalWarningNotification(device);
    }

    if (device.accuracy > 15.0) {
      await showAccuracyWarningNotification(device);
    }

    if (!device.isOnline) {
      await showDeviceOfflineNotification(device);
    }
  }
}
