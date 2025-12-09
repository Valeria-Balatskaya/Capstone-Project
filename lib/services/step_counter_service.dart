import 'package:pedometer/pedometer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class StepData {
  final int steps;
  final DateTime timestamp;
  final String deviceId;

  StepData({
    required this.steps,
    required this.timestamp,
    required this.deviceId,
  });

  Map<String, dynamic> toMap() {
    return {
      'steps': steps,
      'timestamp': timestamp.toIso8601String(),
      'deviceId': deviceId,
    };
  }

  factory StepData.fromMap(Map<String, dynamic> map) {
    return StepData(
      steps: map['steps'] ?? 0,
      timestamp: DateTime.parse(map['timestamp']),
      deviceId: map['deviceId'] ?? '',
    );
  }
}

class StepCounterService {
  Stream<StepCount>? _stepCountStream;
  Stream<PedestrianStatus>? _pedestrianStatusStream;
  StreamSubscription<StepCount>? _stepSubscription;
  StreamSubscription<PedestrianStatus>? _statusSubscription;

  int _currentSteps = 0;
  String _currentStatus = 'unknown';
  DateTime? _lastReset;

  Future<void> initialize() async {
    _loadDailySteps();

    try {
      _stepCountStream = Pedometer.stepCountStream;
      _pedestrianStatusStream = Pedometer.pedestrianStatusStream;

      _stepSubscription = _stepCountStream?.listen(
        _onStepCount,
        onError: _onStepCountError,
      );

      _statusSubscription = _pedestrianStatusStream?.listen(
        _onPedestrianStatus,
        onError: _onPedestrianStatusError,
      );
    } catch (e) {
      print('Step counter initialization error: $e');
    }
  }

  void _onStepCount(StepCount event) async {
    final prefs = await SharedPreferences.getInstance();
    final savedDate = prefs.getString('step_date');
    final today = DateTime.now().toIso8601String().substring(0, 10);

    if (savedDate != today) {
      await prefs.setString('step_date', today);
      await prefs.setInt('daily_steps', event.steps);
      _currentSteps = event.steps;
    } else {
      final baseSteps = prefs.getInt('daily_steps') ?? 0;
      _currentSteps = event.steps - baseSteps;
    }
  }

  void _onPedestrianStatus(PedestrianStatus event) {
    _currentStatus = event.status;
  }

  void _onStepCountError(dynamic error) {
    print('Step count error: $error');
  }

  void _onPedestrianStatusError(dynamic error) {
    print('Pedestrian status error: $error');
  }

  Future<void> _loadDailySteps() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDate = prefs.getString('step_date');
    final today = DateTime.now().toIso8601String().substring(0, 10);

    if (savedDate == today) {
      _currentSteps = prefs.getInt('current_steps') ?? 0;
    } else {
      _currentSteps = 0;
      await prefs.setString('step_date', today);
      await prefs.setInt('current_steps', 0);
    }
  }

  int get currentSteps => _currentSteps;
  String get pedestrianStatus => _currentStatus;

  Future<Map<String, dynamic>> getDailyStats() async {
    final prefs = await SharedPreferences.getInstance();
    final steps = prefs.getInt('current_steps') ?? 0;

    const caloriesPerStep = 0.04;
    final calories = (steps * caloriesPerStep).toInt();

    const kmPerStep = 0.0008;
    final distance = (steps * kmPerStep);

    return {
      'steps': steps,
      'calories': calories,
      'distance': distance,
      'status': _currentStatus,
    };
  }

  Future<void> resetDailySteps() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('current_steps', 0);
    _currentSteps = 0;
  }

  String getActivityLevel(int steps) {
    if (steps < 2000) return 'Sedentary';
    if (steps < 5000) return 'Lightly Active';
    if (steps < 7500) return 'Moderately Active';
    if (steps < 10000) return 'Active';
    return 'Very Active';
  }

  String getMotivationalMessage(int steps) {
    if (steps < 1000) return 'Time to get moving! Every step counts.';
    if (steps < 5000) return 'Good start! Keep it up!';
    if (steps < 10000) return 'Great progress! You\'re on track!';
    return 'Excellent! You\'ve exceeded your daily goal!';
  }

  void dispose() {
    _stepSubscription?.cancel();
    _statusSubscription?.cancel();
  }
}