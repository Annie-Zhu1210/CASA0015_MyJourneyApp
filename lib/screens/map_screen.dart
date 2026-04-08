// lib/screens/map_screen.dart

import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../services/exploration_service.dart';
import '../services/checkin_database.dart';
import '../services/checkin_marker_builder.dart';
import '../models/checkin_location.dart';
import '../widgets/checkin/checkin_level1_dialog.dart';
import '../widgets/checkin/checkin_info_panel.dart';

const double kRevealRadiusMetres = 50.0;
const double kBaseZoom = 15.0;

class MapScreen extends StatefulWidget {
  /// Called whenever a check-in is added, edited, or deleted — so the parent
  /// can refresh the shared [checkIns] list passed to LocationsScreen.
  final VoidCallback? onCheckInsChanged;

  const MapScreen({super.key, this.onCheckInsChanged});

  @override
  State<MapScreen> createState() => MapScreenState();
}

class MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  bool _isLoading = true;
  String _errorMessage = '';
  StreamSubscription<Position>? _locationSubscription;

  List<VisitedPoint> _visitedPoints = [];
  List<Offset> _screenPositions = [];
  double _currentZoom = kBaseZoom;
  bool _isReprojectPending = false;

  /// Called externally via GlobalKey to force a reload of check-ins,
  /// e.g. after a delete or edit from the Locations screen.
  Future<void> refresh() => _loadCheckIns();

  // ── Check-in state ───────────────────────────────────────────────────────
  List<CheckInLocation> _checkIns = [];
  final Map<String, BitmapDescriptor> _markerIcons = {};

  // Level 1 dialog state
  LatLng? _pendingLongPressPosition;
  bool _showLevel1Dialog = false;

  // Info panel state
  CheckInLocation? _selectedCheckIn;
  bool _showInfoPanel = false;

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(0, 0),
    zoom: 2,
  );

  // ── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadVisitedPoints();
    _loadCheckIns();
    _initializeLocation();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  // ── Check-in loading ─────────────────────────────────────────────────────

  Future<void> _loadCheckIns() async {
    final checkIns = await CheckInDatabase.loadAll();
    if (!mounted) return;
    setState(() => _checkIns = checkIns);
    await _buildAllMarkerIcons();
  }

  Future<void> _buildAllMarkerIcons() async {
    for (final c in _checkIns) {
      final icon = await CheckInMarkerBuilder.build(c.emoji);
      if (mounted) {
        setState(() => _markerIcons[c.id] = icon);
      }
    }
  }

  Future<void> _addOrRefreshMarkerIcon(CheckInLocation c) async {
    final icon = await CheckInMarkerBuilder.build(c.emoji);
    if (mounted) {
      setState(() => _markerIcons[c.id] = icon);
    }
  }

  // ── Long press handling ──────────────────────────────────────────────────

  void _onMapLongPress(LatLng position) {
    setState(() {
      _pendingLongPressPosition = position;
      _showLevel1Dialog = true;
      _showInfoPanel = false;
    });
  }

  void _dismissLevel1() {
    setState(() {
      _showLevel1Dialog = false;
      _pendingLongPressPosition = null;
    });
  }

  Future<void> _onCheckInSaved() async {
    await _loadCheckIns();
    widget.onCheckInsChanged?.call();
  }

  // ── Marker tap → info panel ──────────────────────────────────────────────

  void _onCheckInMarkerTapped(CheckInLocation c) {
    setState(() {
      _selectedCheckIn = c;
      _showInfoPanel = true;
      _showLevel1Dialog = false;
    });
  }

  void _closeInfoPanel() {
    setState(() {
      _showInfoPanel = false;
      _selectedCheckIn = null;
    });
  }

  Future<void> _onCheckInEdited() async {
    await _loadCheckIns();
    widget.onCheckInsChanged?.call();
  }

  Future<void> _onCheckInDeleted() async {
    if (_selectedCheckIn != null) {
      _markerIcons.remove(_selectedCheckIn!.id);
    }
    _closeInfoPanel();
    await _loadCheckIns();
    widget.onCheckInsChanged?.call();
  }

  // ── Build marker set ─────────────────────────────────────────────────────

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    if (_currentPosition != null) {
      markers.add(Marker(
        markerId: const MarkerId('current_location'),
        position:
            LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        infoWindow: const InfoWindow(
          title: 'You are here',
          snippet: 'Current Location',
        ),
      ));
    }

    for (final c in _checkIns) {
      final icon = _markerIcons[c.id];
      if (icon == null) continue;
      markers.add(Marker(
        markerId: MarkerId('checkin_${c.id}'),
        position: LatLng(c.latitude, c.longitude),
        icon: icon,
        onTap: () => _onCheckInMarkerTapped(c),
        infoWindow: InfoWindow.noText,
      ));
    }

    return markers;
  }

  // Exploration

  Future<void> _loadVisitedPoints() async {
    final points = await ExplorationService.loadVisitedPoints();
    if (mounted) {
      setState(() => _visitedPoints = points);
      _reprojectAll();
    }
  }

  Future<void> _initializeLocation() async {
    try {
      bool hasPermission = await _handleLocationPermission();
      if (!hasPermission) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Location permission denied';
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _isLoading = false;
      });

      _recordVisit(position);
      _startLocationUpdates();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error getting location: $e';
      });
    }
  }

  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _errorMessage = 'Location services are disabled.');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _errorMessage = 'Location permission denied');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(
          () => _errorMessage = 'Location permissions are permanently denied');
      return false;
    }

    return true;
  }

  void _startLocationUpdates() {
    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 30,
      ),
    ).listen((Position position) {
      if (!mounted) return;
      setState(() => _currentPosition = position);
      _recordVisit(position);
    });
  }

  void _recordVisit(Position position) {
    final newPoint = VisitedPoint(
      latitude: position.latitude,
      longitude: position.longitude,
    );

    if (ExplorationService.shouldAddPoint(newPoint, _visitedPoints,
        thresholdMetres: 30.0)) {
      setState(() {
        _visitedPoints = [..._visitedPoints, newPoint];
      });
      ExplorationService.saveVisitedPoints(_visitedPoints);
      _reprojectAll();
    }
  }

  void _onMapCreated(GoogleMapController controller) async {
    _mapController = controller;
    if (_currentPosition != null) {
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(
                _currentPosition!.latitude, _currentPosition!.longitude),
            zoom: kBaseZoom,
          ),
        ),
      );
    }
    _reprojectAll();
  }

  void _onCameraMove(CameraPosition position) {
    setState(() => _currentZoom = position.zoom);
  }

  void _onCameraIdle() {
    _reprojectAll();
  }

  Future<void> _reprojectAll() async {
    if (_mapController == null || _visitedPoints.isEmpty) return;
    if (_isReprojectPending) return;
    _isReprojectPending = true;

    try {
      final List<Offset> positions = [];
      for (final point in _visitedPoints) {
        final ScreenCoordinate sc = await _mapController!.getScreenCoordinate(
          LatLng(point.latitude, point.longitude),
        );
        positions.add(Offset(sc.x.toDouble(), sc.y.toDouble()));
      }

      if (mounted) {
        setState(() => _screenPositions = positions);
      }
    } catch (_) {
    } finally {
      _isReprojectPending = false;
    }
  }

  double _revealRadius() {
    const double earthCircumference = 40075016.686;
    const double tileSize = 256.0;
    final double lat = _currentPosition?.latitude ?? 0.0;
    final double metersPerPixel = earthCircumference *
        cos(lat * pi / 180.0) /
        (tileSize * pow(2, _currentZoom));
    return kRevealRadiusMetres / metersPerPixel;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── Google Map ───────────────────────────────────────────────────
        GoogleMap(
          onMapCreated: _onMapCreated,
          onCameraMove: _onCameraMove,
          onCameraIdle: _onCameraIdle,
          onLongPress: _onMapLongPress,
          onTap: (_) {
            if (_showLevel1Dialog) _dismissLevel1();
            if (_showInfoPanel) _closeInfoPanel();
          },
          initialCameraPosition: _initialPosition,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          zoomGesturesEnabled: true,
          scrollGesturesEnabled: true,
          tiltGesturesEnabled: true,
          rotateGesturesEnabled: true,
          mapType: MapType.normal,
          markers: _buildMarkers(),
        ),

        // Exploration Path
        if (!_isLoading &&
            _errorMessage.isEmpty &&
            _screenPositions.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: ExplorationPathPainter(
                  screenPositions: _screenPositions,
                  revealRadius: _revealRadius(),
                ),
              ),
            ),
          ),

        // ── Loading ──────────────────────────────────────────────────────
        if (_isLoading)
          Container(
            color: Colors.white,
            child: const Center(
              child: CircularProgressIndicator(
                color: Color.fromARGB(255, 255, 210, 75),
              ),
            ),
          ),

        // ── Error ────────────────────────────────────────────────────────
        if (_errorMessage.isNotEmpty && !_isLoading)
          Container(
            color: Colors.white,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.location_off, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage,
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: Colors.grey[600], fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _isLoading = true;
                          _errorMessage = '';
                        });
                        _initializeLocation();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color.fromARGB(255, 255, 210, 75),
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // ── My location FAB ──────────────────────────────────────────────
        if (!_isLoading && _errorMessage.isEmpty)
          Positioned(
            bottom: 100,
            right: 16,
            child: FloatingActionButton(
              backgroundColor: Colors.white,
              onPressed: () {
                if (_currentPosition != null && _mapController != null) {
                  _mapController!.animateCamera(
                    CameraUpdate.newCameraPosition(
                      CameraPosition(
                        target: LatLng(
                          _currentPosition!.latitude,
                          _currentPosition!.longitude,
                        ),
                        zoom: kBaseZoom,
                      ),
                    ),
                  );
                }
              },
              child: const Icon(
                Icons.my_location,
                color: Color.fromARGB(255, 151, 86, 0),
              ),
            ),
          ),

        // ── Level 1 dialog ───────────────────────────────────────────────
        if (_showLevel1Dialog && _pendingLongPressPosition != null)
          Positioned.fill(
            child: GestureDetector(
              onTap: _dismissLevel1,
              child: Container(
                color: Colors.black.withValues(alpha: 0.25),
                child: CheckInLevel1Dialog(
                  position: _pendingLongPressPosition!,
                  onDismiss: _dismissLevel1,
                  onCheckInSaved: _onCheckInSaved,
                ),
              ),
            ),
          ),

        // ── Info panel ───────────────────────────────────────────────────
        if (_showInfoPanel && _selectedCheckIn != null)
          Positioned.fill(
            child: GestureDetector(
              onTap: _closeInfoPanel,
              child: Container(
                color: Colors.black.withValues(alpha: 0.25),
                child: CheckInInfoPanel(
                  checkin: _selectedCheckIn!,
                  onClose: _closeInfoPanel,
                  onEdited: _onCheckInEdited,
                  onDeleted: _onCheckInDeleted,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// Exploration Path Painter

class ExplorationPathPainter extends CustomPainter {
  final List<Offset> screenPositions;
  final double revealRadius;

  const ExplorationPathPainter({
    required this.screenPositions,
    required this.revealRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (screenPositions.isEmpty) return;

    canvas.saveLayer(Offset.zero & size, Paint());

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.5)
        ..style = PaintingStyle.fill,
    );

    final Paint clearPaint = Paint()..blendMode = ui.BlendMode.clear;

    for (final centre in screenPositions) {
      canvas.drawCircle(centre, revealRadius, clearPaint);

      for (int i = 1; i <= 8; i++) {
        final double extraRadius = revealRadius + (i * revealRadius * 0.06);
        final double alpha = 0.55 * (1.0 - i / 8.0);
        canvas.drawCircle(
          centre,
          extraRadius,
          Paint()
            ..blendMode = ui.BlendMode.clear
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
            ..color = Colors.black.withValues(alpha: alpha),
        );
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(ExplorationPathPainter oldDelegate) {
    return oldDelegate.screenPositions != screenPositions ||
        oldDelegate.revealRadius != revealRadius;
  }
}