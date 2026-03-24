// This file handles saving and loading visited points.

import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
 
class VisitedPoint {
  final double latitude;
  final double longitude;
 
  const VisitedPoint({required this.latitude, required this.longitude});
 
  Map<String, dynamic> toJson() => {
        'lat': latitude,
        'lng': longitude,
      };
 
  factory VisitedPoint.fromJson(Map<String, dynamic> json) => VisitedPoint(
        latitude: json['lat'] as double,
        longitude: json['lng'] as double,
      );
}
 
class ExplorationService {
  static const String _storageKey = 'visited_points';
 
  // Load all visited points from local storage
  static Future<List<VisitedPoint>> loadVisitedPoints() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_storageKey);
    if (jsonString == null) return [];
 
    final List<dynamic> jsonList = json.decode(jsonString);
    return jsonList
        .map((item) => VisitedPoint.fromJson(item as Map<String, dynamic>))
        .toList();
  }
 
  // Save all visited points to local storage
  static Future<void> saveVisitedPoints(List<VisitedPoint> points) async {
    final prefs = await SharedPreferences.getInstance();
    final String jsonString =
        json.encode(points.map((p) => p.toJson()).toList());
    await prefs.setString(_storageKey, jsonString);
  }
 
  // Returns true if newPoint is far enough from all existing points to be worth saving
  static bool shouldAddPoint(
    VisitedPoint newPoint,
    List<VisitedPoint> existingPoints, {
    double thresholdMetres = 30.0,
  }) {
    for (final point in existingPoints) {
      if (distanceInMetres(newPoint, point) < thresholdMetres) {
        return false;
      }
    }
    return true;
  }
 
  // Haversine formula — accurate distance between two lat/lng points in metres
  static double distanceInMetres(VisitedPoint a, VisitedPoint b) {
    const double earthRadius = 6371000.0;
    final double lat1 = a.latitude * pi / 180.0;
    final double lat2 = b.latitude * pi / 180.0;
    final double dLat = (b.latitude - a.latitude) * pi / 180.0;
    final double dLng = (b.longitude - a.longitude) * pi / 180.0;
 
    final double sinDLat = sin(dLat / 2);
    final double sinDLng = sin(dLng / 2);
 
    final double h =
        sinDLat * sinDLat + cos(lat1) * cos(lat2) * sinDLng * sinDLng;
 
    return 2 * earthRadius * asin(sqrt(h));
  }
}