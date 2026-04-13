// lib/widgets/checkin/checkin_level1_dialog.dart

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/weather_service.dart';
import 'checkin_editor.dart';

/// Level 1 floating window: "Add Location" or "Cancel"
/// Appears after a long press on the map.
class CheckInLevel1Dialog extends StatefulWidget {
  final LatLng position;
  final VoidCallback onDismiss;
  final VoidCallback onCheckInSaved;

  const CheckInLevel1Dialog({
    super.key,
    required this.position,
    required this.onDismiss,
    required this.onCheckInSaved,
  });

  @override
  State<CheckInLevel1Dialog> createState() => _CheckInLevel1DialogState();
}

class _CheckInLevel1DialogState extends State<CheckInLevel1Dialog> {
  /// null = not yet asked, true = yes, false = no
  bool? _addWeather;

  /// The fetched weather — null until fetch completes (or if fetch failed)
  WeatherData? _weather;
  bool _fetchingWeather = false;

  Future<void> _fetchWeather() async {
    if (_fetchingWeather) return;
    setState(() => _fetchingWeather = true);
    final weather = await WeatherService.fetchCurrent(
      latitude: widget.position.latitude,
      longitude: widget.position.longitude,
    );
    if (mounted) {
      setState(() {
        _weather = weather;
        _fetchingWeather = false;
      });
    }
  }

  void _onAddLocation() {
    widget.onDismiss();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => CheckInEditor(
        position: widget.position,
        onSaved: widget.onCheckInSaved,
        weatherCondition: _addWeather == true ? _weather?.condition : null,
        weatherTemp: _addWeather == true ? _weather?.tempCelsius : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 280,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEE),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pin icon
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD24B).withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.place_rounded,
                  color: Color(0xFF975600),
                  size: 28,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Save this place?',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3D2000),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Long-pressed location\nwill be saved as a check-in.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.brown[400],
                  height: 1.5,
                ),
              ),

              // ── Weather section ──────────────────────────────────────────
              const SizedBox(height: 18),
              _buildWeatherSection(),

              const SizedBox(height: 22),
              // Add Location button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _onAddLocation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD24B),
                    foregroundColor: const Color(0xFF3D2000),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: const Text(
                    'Add Location',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Cancel button
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: widget.onDismiss,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.brown[400],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeatherSection() {
    // Step 1 — not yet asked
    if (_addWeather == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFD24B).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFFFD24B).withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            const Text('🌤️', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Add current weather?',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF3D2000),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            // Yes button
            GestureDetector(
              onTap: () {
                setState(() => _addWeather = true);
                _fetchWeather();
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD24B),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Yes',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3D2000),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            // No button
            GestureDetector(
              onTap: () => setState(() => _addWeather = false),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.brown.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'No',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.brown[400],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Step 2a — user said No
    if (_addWeather == false) {
      return GestureDetector(
        onTap: () => setState(() => _addWeather = null),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.brown.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Text('🌡️', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'No weather added',
                  style: TextStyle(fontSize: 12, color: Colors.brown[300]),
                ),
              ),
              Text(
                'Undo',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.brown[300],
                  decoration: TextDecoration.underline,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Step 2b — user said Yes, still fetching
    if (_fetchingWeather || _weather == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFD24B).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF975600),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Fetching weather…',
              style: TextStyle(fontSize: 12, color: Colors.brown[400]),
            ),
          ],
        ),
      );
    }

    // Step 2c — user said Yes, weather loaded
    return GestureDetector(
      onTap: () => setState(() => _addWeather = null),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFD24B).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFFFD24B).withValues(alpha: 0.6),
          ),
        ),
        child: Row(
          children: [
            Text(_weather!.emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _weather!.display,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3D2000),
                    ),
                  ),
                  Text(
                    'Will be saved with this check-in',
                    style: TextStyle(fontSize: 10, color: Colors.brown[300]),
                  ),
                ],
              ),
            ),
            Text(
              'Undo',
              style: TextStyle(
                fontSize: 11,
                color: Colors.brown[300],
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}