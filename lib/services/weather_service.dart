import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherData {
  final double temperature;
  final String description;
  final String icon;
  final double humidity;
  final double windSpeed;
  final int pressure;
  final String cityName;
  final double feelsLike;
  final DateTime timestamp;

  WeatherData({
    required this.temperature,
    required this.description,
    required this.icon,
    required this.humidity,
    required this.windSpeed,
    required this.pressure,
    required this.cityName,
    required this.feelsLike,
    required this.timestamp,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      temperature: (json['main']['temp'] as num).toDouble(),
      description: json['weather'][0]['description'],
      icon: json['weather'][0]['icon'],
      humidity: (json['main']['humidity'] as num).toDouble(),
      windSpeed: (json['wind']['speed'] as num).toDouble(),
      pressure: json['main']['pressure'] as int,
      cityName: json['name'],
      feelsLike: (json['main']['feels_like'] as num).toDouble(),
      timestamp: DateTime.now(),
    );
  }

  String get temperatureDisplay => '${temperature.toStringAsFixed(1)}°C';
  String get feelsLikeDisplay => '${feelsLike.toStringAsFixed(1)}°C';
  String get humidityDisplay => '${humidity.toStringAsFixed(0)}%';
  String get windSpeedDisplay => '${windSpeed.toStringAsFixed(1)} m/s';

  String get weatherIconUrl =>
      'https://openweathermap.org/img/wn/$icon@2x.png';

  String get trackingAdvice {
    if (temperature < 0) {
      return 'Cold weather may significantly affect battery performance.';
    } else if (temperature < 5) {
      return 'Low temperature may reduce battery efficiency.';
    } else if (temperature > 35) {
      return 'High temperature detected. Keep device away from direct sunlight.';
    } else if (windSpeed > 15) {
      return 'Strong winds may affect outdoor signal quality.';
    } else if (humidity > 85) {
      return 'High humidity. Ensure device seals are intact.';
    } else if (description.contains('rain') || description.contains('storm')) {
      return 'Weather may affect signal quality. Consider indoor tracking.';
    }
    return 'Good weather conditions for tracking.';
  }
}

class WeatherService {
  static final WeatherService _instance = WeatherService._internal();
  factory WeatherService() => _instance;
  WeatherService._internal();

  static const String _apiKey = '774990cccb0e11257faa6dc060f18e8b';
  static const String _baseUrl =
      'https://api.openweathermap.org/data/2.5/weather';

  WeatherData? _cachedWeather;
  DateTime? _lastFetch;

  Future<WeatherData?> getWeatherByCoordinates(double lat, double lon) async {
    if (_cachedWeather != null &&
        _lastFetch != null &&
        DateTime.now().difference(_lastFetch!).inMinutes < 10) {
      return _cachedWeather;
    }

    try {
      final url = Uri.parse(
          '$_baseUrl?lat=$lat&lon=$lon&appid=$_apiKey&units=metric');
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _cachedWeather = WeatherData.fromJson(data);
        _lastFetch = DateTime.now();
        return _cachedWeather;
      }
      return _getSimulatedWeather();
    } catch (e) {
      return _getSimulatedWeather();
    }
  }

  Future<WeatherData?> getWeatherByCity(String cityName) async {
    try {
      final url =
          Uri.parse('$_baseUrl?q=$cityName&appid=$_apiKey&units=metric');
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return WeatherData.fromJson(data);
      }
      return _getSimulatedWeather();
    } catch (e) {
      return _getSimulatedWeather();
    }
  }

  WeatherData _getSimulatedWeather() {
    final hour = DateTime.now().hour;
    double temp;

    if (hour >= 6 && hour < 12) {
      temp = 12.0 + (hour - 6) * 1.5;
    } else if (hour >= 12 && hour < 18) {
      temp = 21.0 - (hour - 12) * 0.5;
    } else if (hour >= 18 && hour < 22) {
      temp = 18.0 - (hour - 18) * 1.5;
    } else {
      temp = 10.0;
    }

    return WeatherData(
      temperature: temp,
      description: hour >= 6 && hour < 20 ? 'partly cloudy' : 'clear sky',
      icon: hour >= 6 && hour < 20 ? '02d' : '01n',
      humidity: 55 + (hour % 3) * 5.0,
      windSpeed: 3.0 + (hour % 5) * 0.5,
      pressure: 1013,
      cityName: 'Lodz',
      feelsLike: temp - 2,
      timestamp: DateTime.now(),
    );
  }

  void clearCache() {
    _cachedWeather = null;
    _lastFetch = null;
  }
}
