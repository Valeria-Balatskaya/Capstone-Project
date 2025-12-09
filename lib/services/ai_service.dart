import 'dart:math';
import '../models/device_history.dart';
import 'analytics_service.dart';

class AISuggestion {
  final String title;
  final String description;
  final String type;
  final int priority;
  final DateTime timestamp;
  final IconType iconType;

  AISuggestion({
    required this.title,
    required this.description,
    required this.type,
    required this.priority,
    required this.timestamp,
    required this.iconType,
  });
}

enum IconType {
  warning,
  info,
  success,
  prediction,
  alert
}

class AIService {
  final AnalyticsService _analyticsService = AnalyticsService();

  Future<List<AISuggestion>> generateSmartSuggestions(String deviceId) async {
    final suggestions = <AISuggestion>[];
    final history = await _analyticsService.getHistory(deviceId, limit: 50);

    if (history.isEmpty) {
      suggestions.add(AISuggestion(
        title: 'Welcome to AI Assistant',
        description: 'Start tracking to receive intelligent insights and predictions about your device.',
        type: 'info',
        priority: 1,
        timestamp: DateTime.now(),
        iconType: IconType.info,
      ));
      return suggestions;
    }

    suggestions.addAll(_analyzeAccuracyTrends(history));
    suggestions.addAll(_analyzeBatteryHealth(history));
    suggestions.addAll(_detectAnomalies(history));
    suggestions.addAll(_predictNextLocation(history));
    suggestions.addAll(_analyzeSignalQuality(history));
    suggestions.addAll(_analyzeUsagePatterns(history));

    suggestions.sort((a, b) => b.priority.compareTo(a.priority));
    return suggestions.take(10).toList();
  }

  List<AISuggestion> _analyzeAccuracyTrends(List<DeviceHistory> history) {
    final suggestions = <AISuggestion>[];
    if (history.length < 5) return suggestions;

    final recentAccuracy = history.take(10).map((h) => h.accuracy).toList();
    final avgRecent = recentAccuracy.reduce((a, b) => a + b) / recentAccuracy.length;

    if (avgRecent > 10.0) {
      suggestions.add(AISuggestion(
        title: '⚠️ Poor Positioning Accuracy',
        description: 'Average accuracy is ${avgRecent.toStringAsFixed(1)}m. AI suggests: Move device closer to gateways or check for signal interference.',
        type: 'accuracy',
        priority: 4,
        timestamp: DateTime.now(),
        iconType: IconType.warning,
      ));
    } else if (avgRecent < 3.0) {
      suggestions.add(AISuggestion(
        title: '✓ Excellent Signal Quality',
        description: 'Your device maintains exceptional ${avgRecent.toStringAsFixed(1)}m accuracy. Current gateway configuration is optimal.',
        type: 'accuracy',
        priority: 1,
        timestamp: DateTime.now(),
        iconType: IconType.success,
      ));
    }

    final accuracyImproving = _isImprovingTrend(recentAccuracy);
    if (accuracyImproving) {
      suggestions.add(AISuggestion(
        title: '📈 Accuracy Improving',
        description: 'AI detected consistent accuracy improvement over last ${recentAccuracy.length} readings. Keep current setup.',
        type: 'accuracy',
        priority: 2,
        timestamp: DateTime.now(),
        iconType: IconType.info,
      ));
    }

    return suggestions;
  }

  List<AISuggestion> _analyzeBatteryHealth(List<DeviceHistory> history) {
    final suggestions = <AISuggestion>[];
    if (history.length < 5) return suggestions;

    final recentBattery = history.take(10).map((h) => h.battery).toList();
    final avgBattery = recentBattery.reduce((a, b) => a + b) / recentBattery.length;

    if (avgBattery < 20) {
      suggestions.add(AISuggestion(
        title: '🔋 Low Battery Alert',
        description: 'Battery at ${avgBattery.toStringAsFixed(0)}%. AI predicts ~${(avgBattery / 2).toStringAsFixed(0)} hours remaining. Schedule charging soon.',
        type: 'battery',
        priority: 5,
        timestamp: DateTime.now(),
        iconType: IconType.alert,
      ));
    } else if (avgBattery < 40) {
      suggestions.add(AISuggestion(
        title: '⚠️ Battery Warning',
        description: 'Battery at ${avgBattery.toStringAsFixed(0)}%. Consider charging within next ${(avgBattery / 5).toStringAsFixed(0)} hours for optimal uptime.',
        type: 'battery',
        priority: 3,
        timestamp: DateTime.now(),
        iconType: IconType.warning,
      ));
    }

    final batteryDrain = recentBattery.first - recentBattery.last;
    if (batteryDrain > 20 && recentBattery.length >= 5) {
      final drainRate = batteryDrain / recentBattery.length;
      suggestions.add(AISuggestion(
        title: '📉 High Battery Drain Detected',
        description: 'AI detected ${drainRate.toStringAsFixed(1)}% drain per reading. Possible causes: Frequent transmissions, poor signal strength, or device malfunction.',
        type: 'battery',
        priority: 4,
        timestamp: DateTime.now(),
        iconType: IconType.warning,
      ));
    }

    return suggestions;
  }

  List<AISuggestion> _detectAnomalies(List<DeviceHistory> history) {
    final suggestions = <AISuggestion>[];
    if (history.length < 10) return suggestions;

    final accuracySpike = _detectAccuracySpike(history);
    if (accuracySpike) {
      suggestions.add(AISuggestion(
        title: '⚠️ Position Anomaly Detected',
        description: 'AI detected sudden accuracy degradation (${history.first.accuracy.toStringAsFixed(1)}m vs avg ${(history.map((h) => h.accuracy).reduce((a, b) => a + b) / history.length).toStringAsFixed(1)}m). Check for: Gateway failures, signal interference, or device relocation.',
        type: 'anomaly',
        priority: 4,
        timestamp: DateTime.now(),
        iconType: IconType.alert,
      ));
    }

    final recentSignals = history.take(10).map((h) => h.signalStrength).toList();
    final avgSignal = recentSignals.reduce((a, b) => a + b) / recentSignals.length;
    final signalDrop = recentSignals.first < avgSignal - 20;

    if (signalDrop) {
      suggestions.add(AISuggestion(
        title: '📡 Signal Degradation',
        description: 'Current signal ${recentSignals.first.toStringAsFixed(0)}% (avg: ${avgSignal.toStringAsFixed(0)}%). AI suggests: Check gateway connectivity or device antenna orientation.',
        type: 'signal',
        priority: 3,
        timestamp: DateTime.now(),
        iconType: IconType.warning,
      ));
    }

    return suggestions;
  }

  List<AISuggestion> _predictNextLocation(List<DeviceHistory> history) {
    final suggestions = <AISuggestion>[];
    if (history.length < 15) return suggestions;

    final recentPositions = history.take(10).toList();
    final distances = <double>[];

    for (int i = 1; i < recentPositions.length; i++) {
      final dist = _calculateDistance(
        recentPositions[i - 1].latitude,
        recentPositions[i - 1].longitude,
        recentPositions[i].latitude,
        recentPositions[i].longitude,
      );
      distances.add(dist);
    }

    if (distances.isEmpty) return suggestions;

    final avgMovement = distances.reduce((a, b) => a + b) / distances.length;

    if (avgMovement > 100) {
      suggestions.add(AISuggestion(
        title: '🚀 High Mobility Detected',
        description: 'AI detected avg ${avgMovement.toStringAsFixed(0)}m movement between readings. Device appears to be in transit or frequently relocated.',
        type: 'movement',
        priority: 2,
        timestamp: DateTime.now(),
        iconType: IconType.info,
      ));
    } else if (avgMovement < 5) {
      suggestions.add(AISuggestion(
        title: '📍 Static Position',
        description: 'Device is stationary (${avgMovement.toStringAsFixed(1)}m variance). AI suggests: If device should be mobile, check for possible malfunction.',
        type: 'movement',
        priority: 1,
        timestamp: DateTime.now(),
        iconType: IconType.info,
      ));
    }

    return suggestions;
  }

  List<AISuggestion> _analyzeSignalQuality(List<DeviceHistory> history) {
    final suggestions = <AISuggestion>[];
    if (history.length < 10) return suggestions;

    final recentSignals = history.take(20).map((h) => h.signalStrength).toList();
    final avgSignal = recentSignals.reduce((a, b) => a + b) / recentSignals.length;

    if (avgSignal < 70) {
      suggestions.add(AISuggestion(
        title: '📡 Weak Signal Strength',
        description: 'Average signal ${avgSignal.toStringAsFixed(0)}% (Optimal: >85%). AI suggests checking gateway connectivity or device antenna.',
        type: 'signal',
        priority: 3,
        timestamp: DateTime.now(),
        iconType: IconType.warning,
      ));
    } else if (avgSignal > 90) {
      suggestions.add(AISuggestion(
        title: '✓ Excellent Signal Quality',
        description: 'Strong signal strength at ${avgSignal.toStringAsFixed(0)}%. Gateway communication is optimal.',
        type: 'signal',
        priority: 1,
        timestamp: DateTime.now(),
        iconType: IconType.success,
      ));
    }

    final signalVariability = _calculateStandardDeviation(recentSignals.map((s) => s.toDouble()).toList());
    if (signalVariability > 15) {
      suggestions.add(AISuggestion(
        title: '📊 Signal Instability Detected',
        description: 'AI detected high signal variance (σ=${signalVariability.toStringAsFixed(1)}). Possible gateway switching or environmental interference.',
        type: 'signal',
        priority: 2,
        timestamp: DateTime.now(),
        iconType: IconType.info,
      ));
    }

    return suggestions;
  }

  List<AISuggestion> _analyzeUsagePatterns(List<DeviceHistory> history) {
    final suggestions = <AISuggestion>[];
    if (history.length < 20) return suggestions;

    final hourlyActivity = <int, int>{};
    for (var entry in history) {
      final hour = entry.timestamp.hour;
      hourlyActivity[hour] = (hourlyActivity[hour] ?? 0) + 1;
    }

    final peakHour = hourlyActivity.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    final peakActivity = hourlyActivity[peakHour]!;

    suggestions.add(AISuggestion(
      title: '📊 Usage Pattern Analysis',
      description: 'AI identified peak tracking activity at ${peakHour}:00 with $peakActivity data points. Pattern suggests ${_getTimeOfDay(peakHour)} usage preference.',
      type: 'pattern',
      priority: 1,
      timestamp: DateTime.now(),
      iconType: IconType.info,
    ));

    return suggestions;
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371000;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
            sin(dLon / 2) * sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * pi / 180;

  bool _isImprovingTrend(List<double> values) {
    if (values.length < 3) return false;
    int improving = 0;
    for (int i = 1; i < values.length; i++) {
      if (values[i] < values[i - 1]) {
        improving++;
      }
    }
    return improving > values.length * 0.6;
  }

  bool _detectAccuracySpike(List<DeviceHistory> history) {
    if (history.length < 5) return false;
    final avgAccuracy = history.map((h) => h.accuracy).reduce((a, b) => a + b) / history.length;
    return history.first.accuracy > avgAccuracy * 2;
  }

  double _calculateStandardDeviation(List<double> values) {
    if (values.isEmpty) return 0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    final squaredDiffs = values.map((v) => pow(v - mean, 2));
    final variance = squaredDiffs.reduce((a, b) => a + b) / values.length;
    return sqrt(variance);
  }

  String _getTimeOfDay(int hour) {
    if (hour < 6) return 'late night';
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    if (hour < 21) return 'evening';
    return 'night';
  }

  Future<String> analyzeLocationContext(double lat, double lon, String deviceId) async {
    final hour = DateTime.now().hour;
    final history = await _analyticsService.getHistory(deviceId, limit: 10);

    if (history.isEmpty) {
      return '🤖 AI: New device detected. Building usage patterns and learning optimal tracking parameters...';
    }

    final isNight = hour < 6 || hour > 22;
    final avgAccuracy = history.map((h) => h.accuracy).reduce((a, b) => a + b) / history.length;

    if (isNight) {
      return '🌙 AI: Night tracking active. Accuracy ${avgAccuracy.toStringAsFixed(1)}m. Optimal conditions for power-saving mode.';
    } else {
      return '☀️ AI: Day tracking optimal. Accuracy ${avgAccuracy.toStringAsFixed(1)}m. All systems performing normally.';
    }
  }

  Future<Map<String, dynamic>> generatePerformanceScore(String deviceId) async {
    final history = await _analyticsService.getHistory(deviceId, limit: 50);

    // ✅ FIX: Return complete structure even with no data
    if (history.isEmpty) {
      return {
        'score': 0,
        'grade': 'N/A',
        'accuracyScore': 0,  // ← ADDED
        'signalScore': 0,     // ← ADDED
        'batteryScore': 0,    // ← ADDED
        'message': 'No data available yet'
      };
    }

    final avgAccuracy = history.map((h) => h.accuracy).reduce((a, b) => a + b) / history.length;
    final avgSignal = history.map((h) => h.signalStrength).reduce((a, b) => a + b) / history.length;
    final avgBattery = history.map((h) => h.battery).reduce((a, b) => a + b) / history.length;

    final accuracyScore = max(0, 100 - (avgAccuracy * 5)).toInt();
    final signalScore = avgSignal.toInt();
    final batteryScore = avgBattery.toInt();

    final totalScore = ((accuracyScore + signalScore + batteryScore) / 3).toInt();

    String grade;
    if (totalScore >= 90) grade = 'A+';
    else if (totalScore >= 80) grade = 'A';
    else if (totalScore >= 70) grade = 'B';
    else if (totalScore >= 60) grade = 'C';
    else grade = 'D';

    return {
      'score': totalScore,
      'grade': grade,
      'accuracyScore': accuracyScore,
      'signalScore': signalScore,
      'batteryScore': batteryScore,
      'message': 'AI Performance Analysis: Grade $grade ($totalScore/100)',
    };
  }
}