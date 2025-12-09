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

  WeatherData({
    required this.temperature,
    required this.description,
    required this.icon,
    required this.humidity,
    required this.windSpeed,
    required this.pressure,
    required this.cityName,
    required this.feelsLike,
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
    );
  }

  String get temperatureDisplay => '${temperature.toStringAsFixed(1)}°C';
  String get weatherIconUrl => 'https://openweathermap.org/img/wn/$icon@2x.png';
}

class WeatherService {
  static const String _apiKey = '774990cccb0e11257faa6dc060f18e8b';
  static const String _baseUrl = 'https://api.openweathermap.org/data/2.5/weather';

  Future<WeatherData?> getWeatherByCoordinates(double lat, double lon) async {
    if (_apiKey == '774990cccb0e11257faa6dc060f18e8b') {
      return _getMockWeather();
    }

    try {
      final url = Uri.parse('$_baseUrl?lat=$lat&lon=$lon&appid=$_apiKey&units=metric');
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return WeatherData.fromJson(data);
      }
      return _getMockWeather();
    } catch (e) {
      return _getMockWeather();
    }
  }

  Future<WeatherData?> getWeatherByCity(String cityName) async {
    if (_apiKey == '774990cccb0e11257faa6dc060f18e8b') {
      return _getMockWeather();
    }

    try {
      final url = Uri.parse('$_baseUrl?q=$cityName&appid=$_apiKey&units=metric');
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return WeatherData.fromJson(data);
      }
      return _getMockWeather();
    } catch (e) {
      return _getMockWeather();
    }
  }

  WeatherData _getMockWeather() {
    final temp = 15.0 + (DateTime.now().hour - 12) * 0.5;
    return WeatherData(
      temperature: temp,
      description: 'partly cloudy',
      icon: '02d',
      humidity: 65,
      windSpeed: 4.5,
      pressure: 1013,
      cityName: 'Łódź',
      feelsLike: temp - 2,
    );
  }

  String getWeatherAdvice(WeatherData weather) {
    if (weather.temperature < 5) {
      return 'Cold weather may affect device battery performance. Consider indoor tracking.';
    } else if (weather.temperature > 30) {
      return 'High temperature detected. Ensure device is not in direct sunlight.';
    } else if (weather.windSpeed > 10) {
      return 'High winds may affect outdoor gateway signal quality.';
    } else if (weather.humidity > 80) {
      return 'High humidity. Ensure device seals are intact.';
    } else {
      return 'Optimal weather conditions for tracking.';
    }
  }
}