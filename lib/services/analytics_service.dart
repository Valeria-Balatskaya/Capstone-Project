import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/device_history.dart';

class AnalyticsService {
  static const String _historyKey = 'device_history';

  Future<void> addHistoryEntry(DeviceHistory entry) async {
    final history = await getHistory(entry.deviceId);
    history.add(entry);

    if (history.length > 1000) {
      history.removeAt(0);
    }

    await _saveHistory(entry.deviceId, history);
  }

  Future<List<DeviceHistory>> getHistory(String deviceId, {int? limit, DateTime? since}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_historyKey}_$deviceId';
    final historyJson = prefs.getString(key);

    if (historyJson == null) return [];

    final List<dynamic> historyList = json.decode(historyJson);
    var history = historyList
        .map((e) => DeviceHistory.fromMap(Map<String, dynamic>.from(e)))
        .toList();

    if (since != null) {
      history = history.where((h) => h.timestamp.isAfter(since)).toList();
    }

    history.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (limit != null && history.length > limit) {
      history = history.sublist(0, limit);
    }

    return history;
  }

  Future<Map<String, dynamic>> getStatistics(String deviceId, {DateTime? since}) async {
    final history = await getHistory(deviceId, since: since);

    if (history.isEmpty) {
      return {
        'averageAccuracy': 0.0,
        'bestAccuracy': 0.0,
        'worstAccuracy': 0.0,
        'averageBattery': 0,
        'totalDataPoints': 0,
        'averageSignalStrength': 0,
      };
    }

    final accuracies = history.map((h) => h.accuracy).toList();
    final batteries = history.map((h) => h.battery).toList();
    final signals = history.map((h) => h.signalStrength).toList();

    return {
      'averageAccuracy': accuracies.reduce((a, b) => a + b) / accuracies.length,
      'bestAccuracy': accuracies.reduce((a, b) => a < b ? a : b),
      'worstAccuracy': accuracies.reduce((a, b) => a > b ? a : b),
      'averageBattery': (batteries.reduce((a, b) => a + b) / batteries.length).round(),
      'totalDataPoints': history.length,
      'averageSignalStrength': (signals.reduce((a, b) => a + b) / signals.length).round(),
      'timespan': history.first.timestamp.difference(history.last.timestamp),
    };
  }

  Future<void> _saveHistory(String deviceId, List<DeviceHistory> history) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_historyKey}_$deviceId';
    final historyJson = json.encode(history.map((h) => h.toMap()).toList());
    await prefs.setString(key, historyJson);
  }

  Future<void> clearHistory(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${_historyKey}_$deviceId';
    await prefs.remove(key);
  }

  Future<void> simulateHistoryData(String deviceId) async {
    final now = DateTime.now();
    final random = [85, 78, 92, 88, 95, 82, 76, 89, 91, 84, 93, 87, 90, 83, 86];

    for (int i = 0; i < 50; i++) {
      final entry = DeviceHistory(
        deviceId: deviceId,
        latitude: 51.7592 + (i * 0.0001),
        longitude: 19.4560 + (i * 0.0001),
        accuracy: 2.5 + (random[i % 15] * 0.08),
        timestamp: now.subtract(Duration(hours: 50 - i)),
        battery: 100 - (i * 2),
        signalStrength: random[i % 15],
      );
      await addHistoryEntry(entry);
    }
  }
}