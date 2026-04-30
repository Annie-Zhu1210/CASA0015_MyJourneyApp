import 'dart:convert';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:shared_preferences/shared_preferences.dart';
import 'exploration_service.dart';

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

  // ── Main public methods ───────────────────────────────────────────────────

  /// Returns a deduplicated list of cities derived from the given visited points.
  static Future<List<PlaceInfo>> getCitiesFromPoints(
      List<VisitedPoint> points) async {
    return _getPlaces(points, isCity: true);
  }

  /// Returns a deduplicated list of countries derived from the given visited points.
  static Future<List<PlaceInfo>> getCountriesFromPoints(
      List<VisitedPoint> points) async {
    return _getPlaces(points, isCity: false);
  }

  // ── Internal logic ────────────────────────────────────────────────────────

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
      try {
        final List<dynamic> list = json.decode(cachedJson);
        for (final item in list) {
          final place = PlaceInfo.fromJson(item as Map<String, dynamic>);
          placesMap[place.name] = place;
        }
      } catch (_) {
        // Cache was malformed — start fresh
      }
    }

    // Sample every Nth point to avoid excessive geocoding calls.
    // Step of 5 gives better coverage than 10 for small datasets.
    final sampledPoints = _samplePoints(points, step: 5);

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
        // Silently skip points that fail to geocode
      }
    }

    // Persist updated cache
    final encoded =
        json.encode(placesMap.values.map((p) => p.toJson()).toList());
    await prefs.setString(cacheKey, encoded);

    final result = placesMap.values.toList();
    result.sort((a, b) => a.name.compareTo(b.name));
    return result;
  }

  /// Uses the `geocoding` package (same as everywhere else in the app) to
  /// reverse-geocode a lat/lng. No REST API key required.
  static Future<GeocodingResult> _reverseGeocode(
      double lat, double lng) async {
    final placemarks = await geo.placemarkFromCoordinates(
      lat,
      lng,
      localeIdentifier: 'en_US',
    );

    if (placemarks.isEmpty) return const GeocodingResult();

    final p = placemarks.first;

    final city = p.locality?.isNotEmpty == true
        ? p.locality
        : p.subAdministrativeArea?.isNotEmpty == true
            ? p.subAdministrativeArea
            : p.administrativeArea?.isNotEmpty == true
                ? p.administrativeArea
                : null;

    final country =
        p.country?.isNotEmpty == true ? p.country : null;

    // The geocoding package doesn't expose ISO country codes directly,
    // so we derive a 2-letter code from the isoCountryCode field.
    final countryCode =
        p.isoCountryCode?.isNotEmpty == true ? p.isoCountryCode! : '';

    return GeocodingResult(
      city: city,
      country: country,
      countryCode: countryCode,
    );
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

  // ── World exploration percentage ──────────────────────────────────────────

  /// Computes the percentage of Earth's surface covered by visited circles.
  static double computeWorldExploredPercent(List<VisitedPoint> points) {
    if (points.isEmpty) return 0.0;
    const double circleAreaM2 = 3.14159265 * 50 * 50; // ~7854 m²
    const double earthAreaM2 = 5.10072e14;
    final double totalExplored = points.length * circleAreaM2;
    return (totalExplored / earthAreaM2) * 100.0;
  }
}