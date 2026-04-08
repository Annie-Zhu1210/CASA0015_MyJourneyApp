import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'exploration_service.dart';
import '../constants/secrets.dart'; // 

/// Represents a place (city or country) derived from visited GPS points.
class PlaceInfo {
  final String name;    
  final String countryCode; 
  final double latitude;
  final double longitude;

  const PlaceInfo({
    required this.name,
    required this.countryCode,
    required this.latitude,
    required this.longitude,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'countryCode': countryCode,
        'lat': latitude,
        'lng': longitude,
      };

  factory PlaceInfo.fromJson(Map<String, dynamic> json) => PlaceInfo(
        name: json['name'] as String,
        countryCode: json['countryCode'] as String,
        latitude: json['lat'] as double,
        longitude: json['lng'] as double,
      );
}

class GeocodingResult {
  final String? city;
  final String? country;
  final String? countryCode;

  const GeocodingResult({this.city, this.country, this.countryCode});
}

class GeocodingService {
  static const String _citiesCacheKey = 'geocoded_cities';
  static const String _countriesCacheKey = 'geocoded_countries';

  // Main public methods

  /// Returns a deduplicated list of cities derived from the given visited points.
  /// Uses cached results where available; only geocodes new points.
  static Future<List<PlaceInfo>> getCitiesFromPoints(
      List<VisitedPoint> points) async {
    return _getPlaces(points, isCity: true);
  }

  /// Returns a deduplicated list of countries derived from the given visited points.
  static Future<List<PlaceInfo>> getCountriesFromPoints(
      List<VisitedPoint> points) async {
    return _getPlaces(points, isCity: false);
  }

  // Internal logic

  static Future<List<PlaceInfo>> _getPlaces(
    List<VisitedPoint> points, {
    required bool isCity,
  }) async {
    final cacheKey = isCity ? _citiesCacheKey : _countriesCacheKey;
    final prefs = await SharedPreferences.getInstance();

    // Load any existing cache
    final Map<String, PlaceInfo> placesMap = {};
    final String? cachedJson = prefs.getString(cacheKey);
    if (cachedJson != null) {
      final List<dynamic> list = json.decode(cachedJson);
      for (final item in list) {
        final place = PlaceInfo.fromJson(item as Map<String, dynamic>);
        placesMap[place.name] = place;
      }
    }

    // Geocode a sampled subset of points (every Nth point) to avoid
    // excessive API calls, sampling every 10th point
    final sampledPoints = _samplePoints(points, step: 10);

    for (final point in sampledPoints) {
      try {
        final result = await _reverseGeocode(point.latitude, point.longitude);
        final name = isCity ? result.city : result.country;
        final countryCode = result.countryCode ?? '';
        if (name != null && name.isNotEmpty && !placesMap.containsKey(name)) {
          placesMap[name] = PlaceInfo(
            name: name,
            countryCode: countryCode,
            latitude: point.latitude,
            longitude: point.longitude,
          );
        }
      } catch (_) {
        // Silently skip points that fail to geocode (network issues, etc.)
      }
    }

    // Persist updated cache
    final encoded = json.encode(placesMap.values.map((p) => p.toJson()).toList());
    await prefs.setString(cacheKey, encoded);

    final result = placesMap.values.toList();
    result.sort((a, b) => a.name.compareTo(b.name));
    return result;
  }

  /// Calls the Google Maps Geocoding API for a single lat/lng.
  static Future<GeocodingResult> _reverseGeocode(
      double lat, double lng) async {
    final apiKey = Secrets.geocodingApiKey;
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json'
      '?latlng=$lat,$lng&result_type=locality|country&key=$apiKey',
    );

    final response = await http.get(url).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return const GeocodingResult();

    final data = json.decode(response.body) as Map<String, dynamic>;
    final results = data['results'] as List<dynamic>? ?? [];
    if (results.isEmpty) return const GeocodingResult();

    String? city;
    String? country;
    String? countryCode;

    for (final result in results) {
      final components =
          (result['address_components'] as List<dynamic>?) ?? [];
      for (final component in components) {
        final types = List<String>.from(component['types'] as List);
        if (types.contains('locality') && city == null) {
          city = component['long_name'] as String?;
        }
        if (types.contains('country')) {
          country = component['long_name'] as String?;
          countryCode = component['short_name'] as String?;
        }
      }
      if (city != null && country != null) break;
    }

    return GeocodingResult(city: city, country: country, countryCode: countryCode);
  }

  /// Returns every Nth element from the list.
  static List<T> _samplePoints<T>(List<T> list, {required int step}) {
    if (list.isEmpty) return [];
    final result = <T>[];
    for (int i = 0; i < list.length; i += step) {
      result.add(list[i]);
    }
    return result;
  }

  /// Clears the geocoding cache — call this when exploration data is reset.
  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_citiesCacheKey);
    await prefs.remove(_countriesCacheKey);
  }

  // World exploration percentage 

  /// Computes the percentage of Earth's surface covered by visited circles.
  ///
  /// Each visited point has a 50m radius circle (area = π × 50² ≈ 7854 m²).
  /// Earth's surface area = 510,072,000 km² = 5.10072 × 10^14 m².
  static double computeWorldExploredPercent(List<VisitedPoint> points) {
    if (points.isEmpty) return 0.0;
    const double circleAreaM2 = 3.14159265 * 50 * 50; // ~7854 m²
    const double earthAreaM2 = 5.10072e14;
    final double totalExplored = points.length * circleAreaM2;
    return (totalExplored / earthAreaM2) * 100.0;
  }
}