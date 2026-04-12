// lib/services/shake_checkin_service.dart

import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

/// Detects a shake gesture using the accelerometer and fires [onShake].
///
/// A "shake" is defined as three or more acceleration spikes above
/// [threshold] within [windowDuration].  After a shake is detected a
/// [cooldown] lockout prevents further triggers — this stops accidental
/// double-saves from a single shake, and also protects against vibrations
/// from putting the phone in a bag.
///
/// Normal walking produces roughly 1.1–1.3 g of acceleration.
/// The default threshold of 2.7 g is well above that, so casual movement
/// will not trigger a check-in.
class ShakeCheckInService {
  /// Acceleration magnitude (in m/s²) required to count as a spike.
  /// 9.81 m/s² = 1 g, so 2.7 * 9.81 ≈ 26.5 m/s².
  final double threshold;

  /// Number of spikes needed within [windowDuration] to count as a shake.
  final int requiredSpikes;

  /// Time window in which [requiredSpikes] must occur.
  final Duration windowDuration;

  /// Cooldown after a shake is detected — no further triggers during this time.
  final Duration cooldown;

  /// Called once each time a valid shake is detected.
  final VoidCallback onShake;

  StreamSubscription<AccelerometerEvent>? _subscription;
  final List<DateTime> _spikeTimes = [];
  DateTime? _cooldownUntil;
  bool _isRunning = false;

  ShakeCheckInService({
    required this.onShake,
    this.threshold = 2.7 * 9.81,   // 2.7 g
    this.requiredSpikes = 3,
    this.windowDuration = const Duration(milliseconds: 800),
    this.cooldown = const Duration(seconds: 10),
  });

  /// Start listening to the accelerometer.  Safe to call multiple times.
  void start() {
    if (_isRunning) return;
    _isRunning = true;
    _subscription = accelerometerEventStream(
      samplingPeriod: SensorInterval.gameInterval, // ~50 Hz
    ).listen(_onAccelerometer);
  }

  /// Stop listening and clean up.
  void stop() {
    _isRunning = false;
    _subscription?.cancel();
    _subscription = null;
    _spikeTimes.clear();
  }

  void _onAccelerometer(AccelerometerEvent event) {
    // Calculate total acceleration magnitude (removes gravity component
    // direction, keeps the overall force felt by the sensor).
    final double magnitude = sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );

    if (magnitude < threshold) return;

    // We're in the cooldown period — ignore all spikes.
    final now = DateTime.now();
    if (_cooldownUntil != null && now.isBefore(_cooldownUntil!)) return;

    // Record this spike and prune any that are older than [windowDuration].
    _spikeTimes.add(now);
    _spikeTimes.removeWhere(
      (t) => now.difference(t) > windowDuration,
    );

    if (_spikeTimes.length >= requiredSpikes) {
      // Valid shake detected.
      _spikeTimes.clear();
      _cooldownUntil = now.add(cooldown);
      onShake();
    }
  }
}

// Typedef so the service file doesn't need to import flutter/material.dart
typedef VoidCallback = void Function();