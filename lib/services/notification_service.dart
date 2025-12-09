import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class NotificationPreferences {
  bool lowBatteryAlerts;
  bool accuracyWarnings;
  bool movementDetection;
  bool dailySummary;
  int dailySummaryHour;

  NotificationPreferences({
    this.lowBatteryAlerts = true,
    this.accuracyWarnings = true,
    this.movementDetection = false,
    this.dailySummary = true,
    this.dailySummaryHour = 20,
  });

  Map<String, dynamic> toMap() {
    return {
      'lowBatteryAlerts': lowBatteryAlerts,
      'accuracyWarnings': accuracyWarnings,
      'movementDetection': movementDetection,
      'dailySummary': dailySummary,
      'dailySummaryHour': dailySummaryHour,
    };
  }

  factory NotificationPreferences.fromMap(Map<String, dynamic> map) {
    return NotificationPreferences(
      lowBatteryAlerts: map['lowBatteryAlerts'] ?? true,
      accuracyWarnings: map['accuracyWarnings'] ?? true,
      movementDetection: map['movementDetection'] ?? false,
      dailySummary: map['dailySummary'] ?? true,
      dailySummaryHour: map['dailySummaryHour'] ?? 20,
    );
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
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

  void _onNotificationTapped(NotificationResponse response) {
  }

  Future<void> showLowBatteryAlert(String deviceName, int batteryLevel) async {
    const androidDetails = AndroidNotificationDetails(
      'low_battery_channel',
      'Low Battery Alerts',
      channelDescription: 'Alerts when device battery is low',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _notifications.show(
      1,
      '🔋 Low Battery Alert',
      '$deviceName battery at $batteryLevel%. Please charge soon.',
      details,
    );
  }

  Future<void> showAccuracyWarning(String deviceName, double accuracy) async {
    const androidDetails = AndroidNotificationDetails(
      'accuracy_channel',
      'Accuracy Warnings',
      channelDescription: 'Warnings when positioning accuracy is poor',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _notifications.show(
      2,
      '⚠️ Poor Accuracy Detected',
      '$deviceName accuracy: ${accuracy.toStringAsFixed(1)}m. Check gateway connection.',
      details,
    );
  }

  Future<void> showMovementDetected(String deviceName) async {
    const androidDetails = AndroidNotificationDetails(
      'movement_channel',
      'Movement Detection',
      channelDescription: 'Notifications for device movement',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _notifications.show(
      3,
      '📍 Movement Detected',
      '$deviceName location has changed.',
      details,
    );
  }

  Future<void> showDailySummary(String summary) async {
    const androidDetails = AndroidNotificationDetails(
      'summary_channel',
      'Daily Summary',
      channelDescription: 'Daily tracking summary',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _notifications.show(
      4,
      '📊 Daily Tracking Summary',
      summary,
      details,
    );
  }

  Future<void> showSmartSuggestion(String title, String message) async {
    const androidDetails = AndroidNotificationDetails(
      'ai_channel',
      'AI Suggestions',
      channelDescription: 'Smart AI-powered suggestions',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _notifications.show(
      5,
      '🤖 $title',
      message,
      details,
    );
  }

  Future<void> savePreferences(NotificationPreferences prefs) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString('notification_prefs', json.encode(prefs.toMap()));
  }

  Future<NotificationPreferences> loadPreferences() async {
    final sp = await SharedPreferences.getInstance();
    final prefsJson = sp.getString('notification_prefs');
    if (prefsJson == null) {
      return NotificationPreferences();
    }
    return NotificationPreferences.fromMap(json.decode(prefsJson));
  }

  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  Future<void> requestPermissions() async {
    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await _notifications
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
  }
}