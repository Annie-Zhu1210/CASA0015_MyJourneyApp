import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/secrets.dart';

/// Holds the result of a weather fetch.
class WeatherData {
  /// Human-readable condition, e.g. "Sunny", "Partly Cloudy", "Rain"
  final String condition;

  /// Temperature in Celsius, rounded to one decimal place.
  final double tempCelsius;

  const WeatherData({required this.condition, required this.tempCelsius});

  /// e.g. "☀️ Sunny, 18°C"
  String get display => '$emoji $condition, ${tempCelsius.toStringAsFixed(0)}°C';

  /// Maps OpenWeatherMap condition IDs to an emoji.
  String get emoji {
    if (condition.toLowerCase().contains('thunderstorm')) return '⛈️';
    if (condition.toLowerCase().contains('drizzle')) return '🌦️';
    if (condition.toLowerCase().contains('rain')) return '🌧️';
    if (condition.toLowerCase().contains('snow')) return '❄️';
    if (condition.toLowerCase().contains('clear')) return '☀️';
    if (condition.toLowerCase().contains('few clouds')) return '🌤️';
    if (condition.toLowerCase().contains('scattered clouds')) return '⛅';
    if (condition.toLowerCase().contains('cloud')) return '☁️';
    if (condition.toLowerCase().contains('fog') ||
        condition.toLowerCase().contains('mist') ||
        condition.toLowerCase().contains('haze')) return '🌫️';
    return '🌡️';
  }
}

class WeatherService {
  /// Fetches current weather for the given coordinates.
  /// Returns null if the request fails for any reason (no internet, bad key, etc.)
  static Future<WeatherData?> fetchCurrent({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final uri = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather'
        '?lat=$latitude&lon=$longitude'
        '&units=metric'
        '&appid=${Secrets.openWeatherApiKey}',
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final condition =
          (json['weather'] as List).first['description'] as String;
      final temp = (json['main']['temp'] as num).toDouble();

      // Capitalise first letter of condition
      final formatted =
          condition[0].toUpperCase() + condition.substring(1);

      return WeatherData(condition: formatted, tempCelsius: temp);
    } catch (_) {
      return null;
    }
  }
}