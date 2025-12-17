import 'dart:math';
import '../models/device.dart';
import '../models/device_history.dart';
import '../models/ai_models.dart';

class AIService {
  static final AIService _instance = AIService._internal();
  factory AIService() => _instance;
  AIService._internal();

  Future<List<AISuggestion>> generateSmartSuggestions(
    Device device,
    List<DeviceHistory> history,
  ) async {
    final suggestions = <AISuggestion>[];

    if (history.isEmpty) {
      suggestions.add(AISuggestion(
        id: 'welcome_${device.id}',
        title: 'Welcome to AI Assistant',
        description: 'Start collecting data to receive intelligent insights. '
            'The AI will analyze patterns, detect anomalies, and provide recommendations.',
        type: SuggestionType.info,
        priority: SuggestionPriority.low,
        timestamp: DateTime.now(),
        deviceId: device.id,
        confidenceScore: 1.0,
      ));
      return suggestions;
    }

    final anomalyResult = _detectAnomalies(history);
    if (anomalyResult.hasAnomaly) {
      suggestions.add(_createAnomalySuggestion(device.id, anomalyResult));
    }

    final trends = _analyzeTrends(history);
    for (var trend in trends) {
      suggestions.add(_createTrendSuggestion(device.id, trend));
    }

    final patterns = _recognizePatterns(history);
    for (var pattern in patterns) {
      suggestions.add(_createPatternSuggestion(device.id, pattern));
    }

    suggestions.addAll(_generateBatteryInsights(device, history));
    suggestions.addAll(_generateSignalInsights(device, history));
    suggestions.addAll(_generateLocationInsights(device, history));
    suggestions.addAll(_generateTimeBasedInsights(device, history));

    suggestions.sort((a, b) => b.priorityValue.compareTo(a.priorityValue));

    return suggestions.take(10).toList();
  }

  AnomalyDetectionResult _detectAnomalies(List<DeviceHistory> history) {
    if (history.length < 10) {
      return AnomalyDetectionResult(hasAnomaly: false);
    }

    final accuracyValues = history.map((h) => h.accuracy).toList();
    final accuracyStats = _calculateStatistics(accuracyValues);
    
    final recentAccuracy = history.take(5).map((h) => h.accuracy).toList();
    final recentMean = recentAccuracy.reduce((a, b) => a + b) / recentAccuracy.length;
    
    final zScore = (recentMean - accuracyStats['mean']!) / 
                   (accuracyStats['stdDev']! > 0 ? accuracyStats['stdDev']! : 1);

    if (zScore.abs() > 2.0) {
      return AnomalyDetectionResult(
        hasAnomaly: true,
        anomalyType: 'accuracy_deviation',
        severity: min(1.0, zScore.abs() / 3.0),
        description: zScore > 0 
            ? 'Significant accuracy degradation detected'
            : 'Unusual accuracy improvement detected',
        metrics: {
          'zScore': zScore,
          'recentMean': recentMean,
          'historicalMean': accuracyStats['mean'],
          'stdDev': accuracyStats['stdDev'],
        },
      );
    }

    final signalValues = history.map((h) => h.signalStrength.toDouble()).toList();
    final signalStats = _calculateStatistics(signalValues);
    final recentSignal = history.take(5).map((h) => h.signalStrength.toDouble()).toList();
    final recentSignalMean = recentSignal.reduce((a, b) => a + b) / recentSignal.length;
    final signalZScore = (recentSignalMean - signalStats['mean']!) /
                         (signalStats['stdDev']! > 0 ? signalStats['stdDev']! : 1);

    if (signalZScore < -2.0) {
      return AnomalyDetectionResult(
        hasAnomaly: true,
        anomalyType: 'signal_anomaly',
        severity: min(1.0, signalZScore.abs() / 3.0),
        description: 'Significant signal strength drop detected',
        metrics: {
          'zScore': signalZScore,
          'recentMean': recentSignalMean,
          'historicalMean': signalStats['mean'],
        },
      );
    }

    return AnomalyDetectionResult(hasAnomaly: false);
  }

  List<TrendAnalysis> _analyzeTrends(List<DeviceHistory> history) {
    final trends = <TrendAnalysis>[];
    
    if (history.length < 5) return trends;

    final batteryTrend = _calculateLinearRegression(
      history.map((h) => h.battery.toDouble()).toList(),
    );
    
    if (batteryTrend['slope']!.abs() > 0.5) {
      final isDecreasing = batteryTrend['slope']! < 0;
      trends.add(TrendAnalysis(
        metric: 'battery',
        trend: isDecreasing ? 'decreasing' : 'increasing',
        changePercent: batteryTrend['slope']! * 100,
        prediction: isDecreasing 
            ? 'Battery depleting at ${batteryTrend['slope']!.abs().toStringAsFixed(1)}% per reading'
            : 'Battery recovering',
        dataPoints: history.take(20).map((h) => h.battery.toDouble()).toList(),
      ));
    }

    final signalTrend = _calculateLinearRegression(
      history.map((h) => h.signalStrength.toDouble()).toList(),
    );
    
    if (signalTrend['slope']!.abs() > 1.0) {
      final isDecreasing = signalTrend['slope']! < 0;
      trends.add(TrendAnalysis(
        metric: 'signal',
        trend: isDecreasing ? 'decreasing' : 'increasing',
        changePercent: signalTrend['slope']! * 10,
        prediction: isDecreasing 
            ? 'Signal quality degrading over time'
            : 'Signal quality improving',
        dataPoints: history.take(20).map((h) => h.signalStrength.toDouble()).toList(),
      ));
    }

    return trends;
  }

  List<PatternRecognitionResult> _recognizePatterns(List<DeviceHistory> history) {
    final patterns = <PatternRecognitionResult>[];
    
    if (history.length < 24) return patterns;

    final hourlyActivity = <int, List<double>>{};
    for (var entry in history) {
      final hour = entry.timestamp.hour;
      hourlyActivity.putIfAbsent(hour, () => []);
      hourlyActivity[hour]!.add(entry.signalStrength.toDouble());
    }

    int? peakHour;
    double peakSignal = 0;
    hourlyActivity.forEach((hour, signals) {
      if (signals.isNotEmpty) {
        final avgSignal = signals.reduce((a, b) => a + b) / signals.length;
        if (avgSignal > peakSignal) {
          peakSignal = avgSignal;
          peakHour = hour;
        }
      }
    });

    if (peakHour != null) {
      patterns.add(PatternRecognitionResult(
        patternName: 'peak_activity_time',
        description: 'Best signal quality detected around ${peakHour}:00',
        confidence: 0.85,
        patternData: {'peakHour': peakHour, 'peakSignal': peakSignal},
        recommendations: [
          'Schedule important tracking tasks around ${peakHour}:00 for optimal accuracy',
        ],
      ));
    }

    final movements = _calculateMovementDistances(history);
    final avgMovement = movements.isNotEmpty 
        ? movements.reduce((a, b) => a + b) / movements.length 
        : 0.0;

    if (avgMovement < 5.0) {
      patterns.add(PatternRecognitionResult(
        patternName: 'stationary_device',
        description: 'Device appears to be stationary or indoor',
        confidence: 0.9,
        patternData: {'avgMovement': avgMovement},
        recommendations: [
          'Consider power-saving mode for stationary tracking',
          'Indoor positioning algorithms may improve accuracy',
        ],
      ));
    } else if (avgMovement > 50.0) {
      patterns.add(PatternRecognitionResult(
        patternName: 'mobile_device',
        description: 'Device shows high mobility pattern',
        confidence: 0.85,
        patternData: {'avgMovement': avgMovement},
        recommendations: [
          'Increase update frequency for real-time tracking',
          'Enable movement notifications',
        ],
      ));
    }

    return patterns;
  }

  List<AISuggestion> _generateBatteryInsights(
    Device device,
    List<DeviceHistory> history,
  ) {
    final suggestions = <AISuggestion>[];
    
    if (device.battery < 20) {
      final batteryHistory = history.take(10).map((h) => h.battery).toList();
      final avgDrain = batteryHistory.length > 1 
          ? (batteryHistory.first - batteryHistory.last) / batteryHistory.length 
          : 1.0;
      
      final hoursRemaining = device.battery / max(avgDrain, 0.5);
      
      suggestions.add(AISuggestion(
        id: 'battery_critical_${device.id}',
        title: 'Critical Battery Level',
        description: 'Battery at ${device.battery}%. Based on current drain rate, '
            'approximately ${hoursRemaining.toStringAsFixed(0)} hours remaining. '
            'Charge soon to maintain tracking continuity.',
        type: SuggestionType.alert,
        priority: SuggestionPriority.critical,
        timestamp: DateTime.now(),
        deviceId: device.id,
        confidenceScore: 0.95,
        actions: [
          'Charge the device immediately',
          'Check power connection if charging',
          'Consider enabling power-saving mode',
        ],
        analysisData: {
          'currentBattery': device.battery,
          'drainRate': avgDrain,
          'estimatedHours': hoursRemaining,
        },
      ));
    } else if (device.battery < 40) {
      suggestions.add(AISuggestion(
        id: 'battery_warning_${device.id}',
        title: 'Battery Warning',
        description: 'Battery level at ${device.battery}%. Consider scheduling '
            'a charge within the next few hours.',
        type: SuggestionType.warning,
        priority: SuggestionPriority.medium,
        timestamp: DateTime.now(),
        deviceId: device.id,
        confidenceScore: 0.9,
        actions: [
          'Schedule a charging session',
          'Monitor battery consumption rate',
        ],
      ));
    }

    return suggestions;
  }

  List<AISuggestion> _generateSignalInsights(
    Device device,
    List<DeviceHistory> history,
  ) {
    final suggestions = <AISuggestion>[];

    if (history.length >= 5) {
      final recentSignals = history.take(5).map((h) => h.signalStrength).toList();
      final avgSignal = recentSignals.reduce((a, b) => a + b) / recentSignals.length;
      
      if (avgSignal < 50) {
        suggestions.add(AISuggestion(
          id: 'signal_weak_${device.id}',
          title: 'Weak Signal Quality',
          description: 'Average signal strength is ${avgSignal.toStringAsFixed(0)}%. '
              'This may affect positioning accuracy. Consider: relocating device '
              'closer to gateways or checking for interference sources.',
          type: SuggestionType.warning,
          priority: SuggestionPriority.high,
          timestamp: DateTime.now(),
          deviceId: device.id,
          confidenceScore: 0.88,
          actions: [
            'Move device closer to LoRa gateway',
            'Check for RF interference sources nearby',
            'Verify antenna connection and orientation',
          ],
          analysisData: {
            'avgSignal': avgSignal,
            'samples': recentSignals,
          },
        ));
      } else if (avgSignal > 85) {
        suggestions.add(AISuggestion(
          id: 'signal_excellent_${device.id}',
          title: 'Excellent Signal Quality',
          description: 'Signal strength averaging ${avgSignal.toStringAsFixed(0)}%. '
              'Gateway communication is optimal for precise positioning.',
          type: SuggestionType.success,
          priority: SuggestionPriority.low,
          timestamp: DateTime.now(),
          deviceId: device.id,
          confidenceScore: 0.92,
          actions: [
            'Maintain current device placement',
            'Consider this location for other devices',
          ],
        ));
      }
    }

    return suggestions;
  }

  List<AISuggestion> _generateLocationInsights(
    Device device,
    List<DeviceHistory> history,
  ) {
    final suggestions = <AISuggestion>[];

    if (device.accuracy > 10.0) {
      suggestions.add(AISuggestion(
        id: 'accuracy_poor_${device.id}',
        title: 'Poor Positioning Accuracy',
        description: 'Current accuracy is ${device.accuracy.toStringAsFixed(1)}m. '
            'AI analysis suggests: check gateway connectivity, verify device '
            'antenna orientation, or consider environmental interference.',
        type: SuggestionType.warning,
        priority: SuggestionPriority.high,
        timestamp: DateTime.now(),
        deviceId: device.id,
        confidenceScore: 0.85,
        actions: [
          'Verify gateway connectivity and range',
          'Check device antenna orientation',
          'Remove potential interference sources',
          'Consider adding additional gateways',
        ],
        analysisData: {
          'currentAccuracy': device.accuracy,
          'threshold': 10.0,
        },
      ));
    }

    return suggestions;
  }

  List<AISuggestion> _generateTimeBasedInsights(
    Device device,
    List<DeviceHistory> history,
  ) {
    final suggestions = <AISuggestion>[];
    final hour = DateTime.now().hour;

    if (hour >= 22 || hour <= 6) {
      suggestions.add(AISuggestion(
        id: 'night_mode_${device.id}',
        title: 'Night Mode Recommendation',
        description: 'Current time suggests reduced activity. Consider enabling '
            'power-saving mode to extend battery life during low-activity hours.',
        type: SuggestionType.insight,
        priority: SuggestionPriority.low,
        timestamp: DateTime.now(),
        deviceId: device.id,
        confidenceScore: 0.75,
        actions: [
          'Enable power-saving mode',
          'Reduce tracking frequency until morning',
        ],
      ));
    }

    return suggestions;
  }

  AISuggestion _createAnomalySuggestion(
    String deviceId,
    AnomalyDetectionResult anomaly,
  ) {
    return AISuggestion(
      id: 'anomaly_${anomaly.anomalyType}_$deviceId',
      title: 'Anomaly Detected: ${_formatAnomalyType(anomaly.anomalyType)}',
      description: '${anomaly.description}. Severity: '
          '${(anomaly.severity * 100).toStringAsFixed(0)}%. '
          'AI recommends investigating potential causes.',
      type: SuggestionType.alert,
      priority: anomaly.severity > 0.7 
          ? SuggestionPriority.critical 
          : SuggestionPriority.high,
      timestamp: DateTime.now(),
      deviceId: deviceId,
      confidenceScore: 1.0 - anomaly.severity * 0.2,
      analysisData: anomaly.metrics,
    );
  }

  AISuggestion _createTrendSuggestion(String deviceId, TrendAnalysis trend) {
    return AISuggestion(
      id: 'trend_${trend.metric}_$deviceId',
      title: '${_capitalize(trend.metric)} Trend: ${_capitalize(trend.trend)}',
      description: trend.prediction,
      type: trend.trend == 'decreasing' 
          ? SuggestionType.warning 
          : SuggestionType.info,
      priority: SuggestionPriority.medium,
      timestamp: DateTime.now(),
      deviceId: deviceId,
      confidenceScore: 0.8,
      analysisData: {
        'changePercent': trend.changePercent,
        'dataPoints': trend.dataPoints.length,
      },
    );
  }

  AISuggestion _createPatternSuggestion(
    String deviceId,
    PatternRecognitionResult pattern,
  ) {
    return AISuggestion(
      id: 'pattern_${pattern.patternName}_$deviceId',
      title: 'Pattern: ${_formatPatternName(pattern.patternName)}',
      description: '${pattern.description}. '
          '${pattern.recommendations.isNotEmpty ? pattern.recommendations.first : ''}',
      type: SuggestionType.insight,
      priority: SuggestionPriority.low,
      timestamp: DateTime.now(),
      deviceId: deviceId,
      confidenceScore: pattern.confidence,
      analysisData: pattern.patternData,
    );
  }

  PerformanceScore calculatePerformanceScore(
    Device device,
    List<DeviceHistory> history,
  ) {
    if (history.isEmpty) {
      return PerformanceScore.empty();
    }

    final avgAccuracy = history.map((h) => h.accuracy).reduce((a, b) => a + b) / 
                        history.length;
    final avgSignal = history.map((h) => h.signalStrength).reduce((a, b) => a + b) / 
                      history.length;
    final avgBattery = history.map((h) => h.battery).reduce((a, b) => a + b) / 
                       history.length;

    final accuracyScore = max(0, min(100, (100 - avgAccuracy * 5).toInt()));
    final signalScore = avgSignal.toInt();
    final batteryScore = avgBattery.toInt();
    
    final goodReadings = history.where((h) => h.signalStrength > 40).length;
    final uptimeScore = ((goodReadings / history.length) * 100).toInt();

    final overallScore = ((accuracyScore + signalScore + batteryScore + uptimeScore) / 4).toInt();

    String grade;
    if (overallScore >= 90) grade = 'A+';
    else if (overallScore >= 85) grade = 'A';
    else if (overallScore >= 80) grade = 'A-';
    else if (overallScore >= 75) grade = 'B+';
    else if (overallScore >= 70) grade = 'B';
    else if (overallScore >= 65) grade = 'B-';
    else if (overallScore >= 60) grade = 'C+';
    else if (overallScore >= 55) grade = 'C';
    else grade = 'D';

    final improvements = <String>[];
    if (accuracyScore < 70) improvements.add('Improve gateway positioning');
    if (signalScore < 70) improvements.add('Check signal interference');
    if (batteryScore < 50) improvements.add('Schedule regular charging');

    String summary;
    if (overallScore >= 85) {
      summary = 'Excellent performance. Device operating optimally with strong signal and good accuracy.';
    } else if (overallScore >= 70) {
      summary = 'Good overall performance. Minor improvements possible in ${signalScore < accuracyScore ? "signal quality" : "positioning accuracy"}.';
    } else if (overallScore >= 55) {
      summary = 'Average performance. Consider optimizing ${improvements.isNotEmpty ? improvements.first.toLowerCase() : "device placement"}.';
    } else {
      summary = 'Performance needs attention. ${improvements.isNotEmpty ? improvements.join(". ") : "Review device configuration."}';
    }

    return PerformanceScore(
      overallScore: overallScore,
      grade: grade,
      accuracyScore: accuracyScore,
      signalScore: signalScore,
      batteryScore: batteryScore,
      uptimeScore: uptimeScore,
      improvements: improvements,
      breakdown: {
        'avgAccuracy': avgAccuracy,
        'avgSignal': avgSignal,
        'avgBattery': avgBattery,
        'totalReadings': history.length,
      },
      summary: summary,
    );
  }

  String getContextualAnalysis(Device device, List<DeviceHistory> history) {
    final hour = DateTime.now().hour;
    final isNight = hour < 6 || hour > 22;

    if (history.isEmpty) {
      return 'New device detected. AI is building usage patterns and learning '
          'optimal tracking parameters. Data collection in progress...';
    }

    final avgAccuracy = history.take(10).map((h) => h.accuracy).reduce((a, b) => a + b) / 
                        min(10, history.length);

    if (isNight) {
      return 'Night tracking active. Current accuracy: ${avgAccuracy.toStringAsFixed(1)}m. '
          'Reduced activity detected. Power-saving optimizations recommended.';
    }

    final avgSignal = history.take(10).map((h) => h.signalStrength).reduce((a, b) => a + b) / 
                      min(10, history.length);

    if (avgSignal > 80) {
      return 'Optimal tracking conditions. Accuracy: ${avgAccuracy.toStringAsFixed(1)}m, '
          'Signal: ${avgSignal.toStringAsFixed(0)}%. All systems performing well.';
    } else if (avgSignal > 50) {
      return 'Good tracking conditions. Accuracy: ${avgAccuracy.toStringAsFixed(1)}m. '
          'Minor signal fluctuations detected but within acceptable range.';
    } else {
      return 'Challenging conditions detected. Accuracy: ${avgAccuracy.toStringAsFixed(1)}m, '
          'Signal: ${avgSignal.toStringAsFixed(0)}%. Consider repositioning device.';
    }
  }

  Map<String, double> _calculateStatistics(List<double> values) {
    if (values.isEmpty) {
      return {'mean': 0.0, 'stdDev': 0.0};
    }

    final mean = values.reduce((a, b) => a + b) / values.length;
    final squaredDiffs = values.map((v) => pow(v - mean, 2));
    final variance = squaredDiffs.reduce((a, b) => a + b) / values.length;
    final stdDev = sqrt(variance);

    return {'mean': mean, 'stdDev': stdDev};
  }

  Map<String, double> _calculateLinearRegression(List<double> values) {
    if (values.length < 2) {
      return {'slope': 0.0, 'intercept': 0.0};
    }

    final n = values.length;
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;

    for (int i = 0; i < n; i++) {
      sumX += i;
      sumY += values[i];
      sumXY += i * values[i];
      sumX2 += i * i;
    }

    final slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
    final intercept = (sumY - slope * sumX) / n;

    return {'slope': slope, 'intercept': intercept};
  }

  List<double> _calculateMovementDistances(List<DeviceHistory> history) {
    final distances = <double>[];
    
    for (int i = 1; i < history.length && i < 50; i++) {
      final dist = _haversineDistance(
        history[i - 1].latitude,
        history[i - 1].longitude,
        history[i].latitude,
        history[i].longitude,
      );
      distances.add(dist);
    }

    return distances;
  }

  double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
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

  String _formatAnomalyType(String type) {
    return type.split('_').map((w) => _capitalize(w)).join(' ');
  }

  String _formatPatternName(String name) {
    return name.split('_').map((w) => _capitalize(w)).join(' ');
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }
}
