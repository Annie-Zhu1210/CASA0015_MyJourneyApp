import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import '../services/exploration_service.dart';
import '../services/checkin_database.dart';
import '../services/checkin_marker_builder.dart';
import '../services/avatar_marker_builder.dart';
import '../services/user_profile_service.dart';
import '../services/shake_checkin_service.dart';
import '../models/checkin_location.dart';
import '../widgets/checkin/checkin_level1_dialog.dart';
import '../widgets/checkin/checkin_info_panel.dart';
import '../constants/checkin_labels.dart';
import 'package:firebase_auth/firebase_auth.dart';

const double kRevealRadiusMetres = 50.0;
const double kBaseZoom = 15.0;

/// Check-in markers reach full size at or above this zoom.
const double kFullSizeZoom = 14.0;

/// Check-in markers reach minimum size at or below this zoom.
const double kMinSizeZoom = 10.0;

class MapScreen extends StatefulWidget {
  final VoidCallback? onCheckInsChanged;
  final String mapStyle;

  const MapScreen({
    super.key,
    this.onCheckInsChanged,
    this.mapStyle = 'standard',
  });

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

  // ── Check-in state ────────────────────────────────────────────────────────
  List<CheckInLocation> _checkIns = [];

  /// Cache keyed "${checkinId}_${emoji}_${scaleBucket}" — rebuilt only when emoji or bucket changes.
  final Map<String, BitmapDescriptor> _checkinCache = {};

  // ── Avatar marker cache ───────────────────────────────────────────────────
  /// Cache keyed by avatar scale bucket (0–4).
  final Map<int, BitmapDescriptor> _avatarCache = {};
  String? _cachedPhotoUrl;
  String? _cachedDisplayName;
  bool _avatarBuilding = false;

  // ── Dialog / panel state ──────────────────────────────────────────────────
  LatLng? _pendingLongPressPosition;
  bool _showLevel1Dialog = false;
  CheckInLocation? _selectedCheckIn;
  bool _showInfoPanel = false;

  // ── Shake check-in ────────────────────────────────────────────────────────
  late ShakeCheckInService _shakeService;

  // Toast overlay state
  OverlayEntry? _toastEntry;

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(0, 0),
    zoom: 2,
  );

  // ── Public API (called via GlobalKey) ─────────────────────────────────────

  Future<void> refresh() => _loadCheckIns();

  Future<void> refreshAvatar() async {
    _avatarCache.clear();
    _cachedPhotoUrl = null;
    _cachedDisplayName = null;
    await _ensureAvatarBucket(_avatarScaleBucket(_avatarScale(_currentZoom)));
  }

  // ── Map style ─────────────────────────────────────────────────────────────

  Future<void> _applyMapStyle() async {
    if (_mapController == null) return;
    if (widget.mapStyle == 'dark') {
      await _mapController!.setMapStyle(UserProfileService.darkMapStyle);
    } else {
      await _mapController!.setMapStyle(null);
    }
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadVisitedPoints();
    _loadCheckIns();
    _initializeLocation();
    _ensureAvatarBucket(_avatarScaleBucket(1.0));

    // Initialise the shake service — starts listening immediately.
    _shakeService = ShakeCheckInService(onShake: _onShakeDetected);
    _shakeService.start();
  }

  @override
  void didUpdateWidget(MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mapStyle != widget.mapStyle) _applyMapStyle();
  }

  @override
  void dispose() {
    _shakeService.stop();
    _locationSubscription?.cancel();
    _mapController?.dispose();
    _toastEntry?.remove();
    super.dispose();
  }

  // ── Shake check-in ────────────────────────────────────────────────────────

  /// Called by [ShakeCheckInService] whenever a valid shake is detected.
  Future<void> _onShakeDetected() async {
    // We need a GPS fix to save a check-in.
    if (_currentPosition == null) return;

    // Don't trigger if any dialog/panel is already open — it would be
    // confusing to save silently while the user is interacting with the UI.
    if (_showLevel1Dialog || _showInfoPanel) return;

    // Determine the auto-incremented name: "Untitled N"
    // Count how many existing check-ins already have a name matching
    // "Untitled N" so the new one always gets the next available number.
    final untitledCount = _checkIns
        .where((c) =>
            c.name != null &&
            RegExp(r'^Untitled \d+$').hasMatch(c.name!))
        .length;
    final newName = 'Untitled ${untitledCount + 1}';

    // Use the first preset label as the default (⭐ Favourite).
    final defaultLabel = kPresetLabels.first;

    final now = DateTime.now();
    final newCheckIn = CheckInLocation(
      id: const Uuid().v4(),
      latitude: _currentPosition!.latitude,
      longitude: _currentPosition!.longitude,
      emoji: defaultLabel.emoji,
      labelWord: defaultLabel.word,
      name: newName,
      details: null,
      mediaPaths: [],
      createdAt: now,
      updatedAt: now,
    );

    await CheckInDatabase.insert(newCheckIn);
    await _loadCheckIns();
    widget.onCheckInsChanged?.call();

    // Show a brief toast so the user knows the shake worked.
    _showShakeToast(newName, defaultLabel.emoji);
  }

  /// Displays a small floating toast for 2.5 seconds then removes it.
  void _showShakeToast(String name, String emoji) {
    // Remove any existing toast first (in case of rapid shake).
    _toastEntry?.remove();
    _toastEntry = null;

    final overlay = Overlay.of(context);

    _toastEntry = OverlayEntry(
      builder: (_) => _ShakeToast(emoji: emoji, name: name),
    );

    overlay.insert(_toastEntry!);

    // Auto-dismiss after 2.5 seconds.
    Future.delayed(const Duration(milliseconds: 2500), () {
      _toastEntry?.remove();
      _toastEntry = null;
    });
  }

  // ── Visited points ────────────────────────────────────────────────────────

  Future<void> _loadVisitedPoints() async {
    final points = await ExplorationService.loadVisitedPoints();
    if (mounted) {
      setState(() => _visitedPoints = points);
      _reprojectAll();
    }
  }

  // ── Avatar builder ────────────────────────────────────────────────────────

  Future<void> _ensureAvatarBucket(int bucket) async {
    if (_avatarCache.containsKey(bucket)) return;
    if (_avatarBuilding) return;
    _avatarBuilding = true;

    try {
      final user = FirebaseAuth.instance.currentUser;
      final profile = await UserProfileService.getProfile();
      final photoUrl = (profile?['photoUrl'] as String?)?.isNotEmpty == true
          ? profile!['photoUrl'] as String
          : user?.photoURL ?? '';
      final displayName =
          (profile?['displayName'] as String?) ?? user?.displayName ?? '?';

      if (photoUrl != _cachedPhotoUrl || displayName != _cachedDisplayName) {
        _avatarCache.clear();
        _cachedPhotoUrl = photoUrl;
        _cachedDisplayName = displayName;
      }

      if (_avatarCache.containsKey(bucket)) return;

      final scale = _avatarScaleFromBucket(bucket);
      final dpr = ui.window.devicePixelRatio;

      final marker = await AvatarMarkerBuilder.build(
        photoUrl: photoUrl.isNotEmpty ? photoUrl : null,
        displayName: displayName,
        scale: scale,
        devicePixelRatio: dpr,
      );

      if (mounted) setState(() => _avatarCache[bucket] = marker);
    } finally {
      _avatarBuilding = false;
    }
  }

  // ── Avatar scale helpers ──────────────────────────────────────────────────

  double _avatarScale(double zoom) {
    if (zoom >= kFullSizeZoom) return 1.0;
    if (zoom <= kMinSizeZoom) return 0.5;
    return 0.5 +
        0.5 * ((zoom - kMinSizeZoom) / (kFullSizeZoom - kMinSizeZoom));
  }

  int _avatarScaleBucket(double scale) => (scale * 4).round();

  double _avatarScaleFromBucket(int bucket) =>
      (bucket / 4.0).clamp(0.5, 1.0);

  // ── Check-in scale helpers ────────────────────────────────────────────────

  double _checkinScale(double zoom) {
    if (zoom >= kFullSizeZoom) return 1.0;
    if (zoom <= kMinSizeZoom) return 0.35;
    return 0.35 +
        0.65 * ((zoom - kMinSizeZoom) / (kFullSizeZoom - kMinSizeZoom));
  }

  int _checkinScaleBucket(double scale) => (scale * 6).round();

  // ── Check-in loading ──────────────────────────────────────────────────────

  Future<void> _loadCheckIns() async {
    final checkIns = await CheckInDatabase.loadAll();
    if (!mounted) return;
    setState(() => _checkIns = checkIns);
    await _buildCheckinMarkersForZoom(_currentZoom);
  }

  Future<void> _buildCheckinMarkersForZoom(double zoom) async {
    final scale  = _checkinScale(zoom);
    final bucket = _checkinScaleBucket(scale);
    for (final c in _checkIns) {
      final key = '${c.id}_${c.emoji}_$bucket';
      if (_checkinCache.containsKey(key)) continue;
      final icon = await CheckInMarkerBuilder.build(c.emoji, scale: scale);
      if (mounted) setState(() => _checkinCache[key] = icon);
    }
  }

  // ── Marker set ────────────────────────────────────────────────────────────

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    final avatarBucket  = _avatarScaleBucket(_avatarScale(_currentZoom));
    final checkinScale  = _checkinScale(_currentZoom);
    final checkinBucket = _checkinScaleBucket(checkinScale);

    // ── User avatar marker ────────────────────────────────────────────────
    final avatarIcon = _avatarCache[avatarBucket];
    if (_currentPosition != null && avatarIcon != null) {
      markers.add(Marker(
        markerId: const MarkerId('current_user'),
        position: LatLng(
            _currentPosition!.latitude, _currentPosition!.longitude),
        icon:   avatarIcon,
        anchor: const Offset(0.5, 1.0),
        zIndex: 10,
        infoWindow: InfoWindow.noText,
      ));
    }

    // ── Check-in markers ──────────────────────────────────────────────────
    for (final c in _checkIns) {
      final icon = _checkinCache['${c.id}_${c.emoji}_$checkinBucket'];
      if (icon == null) continue;
      markers.add(Marker(
        markerId: MarkerId('checkin_${c.id}'),
        position: LatLng(c.latitude, c.longitude),
        icon:     icon,
        anchor:   const Offset(0.5, 1.0),
        onTap:    () => _onCheckInMarkerTapped(c),
        infoWindow: InfoWindow.noText,
      ));
    }

    return markers;
  }


  // ── Long-press / check-in ─────────────────────────────────────────────────

  void _onMapLongPress(LatLng position) {
    setState(() {
      _pendingLongPressPosition = position;
      _showLevel1Dialog = true;
      _showInfoPanel = false;
    });
  }

  void _dismissLevel1() => setState(() {
        _showLevel1Dialog = false;
        _pendingLongPressPosition = null;
      });

  Future<void> _onCheckInSaved() async {
    await _loadCheckIns();
    widget.onCheckInsChanged?.call();
  }

  // ── Info panel ────────────────────────────────────────────────────────────

  void _onCheckInMarkerTapped(CheckInLocation c) {
    setState(() {
      _selectedCheckIn  = c;
      _showInfoPanel    = true;
      _showLevel1Dialog = false;
    });
  }

  void _closeInfoPanel() => setState(() {
        _showInfoPanel   = false;
        _selectedCheckIn = null;
      });

  Future<void> _onCheckInEdited() async {
    await _loadCheckIns();
    widget.onCheckInsChanged?.call();
  }

  Future<void> _onCheckInDeleted() async {
    if (_selectedCheckIn != null) {
      _checkinCache.removeWhere((k, _) => k.startsWith(_selectedCheckIn!.id));
    }
    _closeInfoPanel();
    await _loadCheckIns();
    widget.onCheckInsChanged?.call();
  }

  // ── Location ──────────────────────────────────────────────────────────────

  Future<void> _initializeLocation() async {
    try {
      if (!await _handleLocationPermission()) {
        setState(() {
          _isLoading    = false;
          _errorMessage = 'Location permission denied';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentPosition = position;
        _isLoading       = false;
      });
      _recordVisit(position);
      _startLocationUpdates();
    } catch (e) {
      setState(() {
        _isLoading    = false;
        _errorMessage = 'Error getting location: $e';
      });
    }
  }

  Future<bool> _handleLocationPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      setState(() => _errorMessage = 'Location services are disabled.');
      return false;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) {
        setState(() => _errorMessage = 'Location permission denied');
        return false;
      }
    }
    if (perm == LocationPermission.deniedForever) {
      setState(
          () => _errorMessage = 'Location permissions are permanently denied');
      return false;
    }
    return true;
  }

  void _startLocationUpdates() {
    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy:       LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((position) {
      if (!mounted) return;
      setState(() {
        _currentPosition = position;
      });
      _recordVisit(position);
    });
  }

  void _recordVisit(Position position) {
    final pt = VisitedPoint(
        latitude: position.latitude, longitude: position.longitude);
    if (ExplorationService.shouldAddPoint(pt, _visitedPoints,
        thresholdMetres: 30.0)) {
      setState(() => _visitedPoints = [..._visitedPoints, pt]);
      ExplorationService.saveVisitedPoints(_visitedPoints);
      _reprojectAll();
    }
  }

  // ── Camera ────────────────────────────────────────────────────────────────

  void _onMapCreated(GoogleMapController controller) async {
    _mapController = controller;
    if (_currentPosition != null) {
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(CameraPosition(
          target: LatLng(
              _currentPosition!.latitude, _currentPosition!.longitude),
          zoom: kBaseZoom,
        )),
      );
    }
    _reprojectAll();
    _applyMapStyle();
  }

  void _onCameraMove(CameraPosition position) {
    final newZoom = position.zoom;
    if (newZoom != _currentZoom) {
      setState(() => _currentZoom = newZoom);
      _ensureAvatarBucket(_avatarScaleBucket(_avatarScale(newZoom)));
    }
  }

  void _onCameraIdle() {
    _reprojectAll();
    _buildCheckinMarkersForZoom(_currentZoom);
  }

  Future<void> _reprojectAll() async {
    if (_mapController == null || _visitedPoints.isEmpty) return;
    if (_isReprojectPending) return;
    _isReprojectPending = true;
    try {
      final positions = <Offset>[];
      for (final pt in _visitedPoints) {
        final sc = await _mapController!
            .getScreenCoordinate(LatLng(pt.latitude, pt.longitude));
        positions.add(Offset(sc.x.toDouble(), sc.y.toDouble()));
      }
      if (mounted) setState(() => _screenPositions = positions);
    } catch (_) {
    } finally {
      _isReprojectPending = false;
    }
  }

  double _revealRadius() {
    const double earthCircumference = 40075016.686;
    const double tileSize = 256.0;
    final double lat   = _currentPosition?.latitude ?? 0.0;
    final double mpp   = earthCircumference *
        cos(lat * pi / 180.0) /
        (tileSize * pow(2, _currentZoom));
    return kRevealRadiusMetres / mpp;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      // ── Google Map ─────────────────────────────────────────────────────
      GoogleMap(
        onMapCreated:      _onMapCreated,
        onCameraMove:      _onCameraMove,
        onCameraIdle:      _onCameraIdle,
        onLongPress:       _onMapLongPress,
        onTap: (_) {
          if (_showLevel1Dialog) _dismissLevel1();
          if (_showInfoPanel)    _closeInfoPanel();
        },
        initialCameraPosition: _initialPosition,
        myLocationEnabled:       true,
        myLocationButtonEnabled: false,
        zoomControlsEnabled:     false,
        zoomGesturesEnabled:     true,
        scrollGesturesEnabled:   true,
        tiltGesturesEnabled:     true,
        rotateGesturesEnabled:   true,
        mapType: widget.mapStyle == 'satellite'
            ? MapType.satellite
            : MapType.normal,
        markers: _buildMarkers(),
      ),

      // ── Exploration fog ────────────────────────────────────────────────
      if (!_isLoading && _errorMessage.isEmpty && _screenPositions.isNotEmpty)
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: ExplorationPathPainter(
                screenPositions: _screenPositions,
                revealRadius:    _revealRadius(),
              ),
            ),
          ),
        ),

      // ── Loading ────────────────────────────────────────────────────────
      if (_isLoading)
        Container(
          color: Colors.white,
          child: const Center(
            child: CircularProgressIndicator(
                color: Color.fromARGB(255, 255, 210, 75)),
          ),
        ),

      // ── Error ──────────────────────────────────────────────────────────
      if (_errorMessage.isNotEmpty && !_isLoading)
        Container(
          color: Colors.white,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_off, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(_errorMessage,
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: Colors.grey[600], fontSize: 16)),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _isLoading    = true;
                        _errorMessage = '';
                      });
                      _initializeLocation();
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color.fromARGB(255, 255, 210, 75)),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),

      // ── My-location FAB ────────────────────────────────────────────────
      if (!_isLoading && _errorMessage.isEmpty)
        Positioned(
          bottom: 100,
          right:  16,
          child: FloatingActionButton(
            backgroundColor: Colors.white,
            onPressed: () {
              if (_currentPosition != null && _mapController != null) {
                _mapController!.animateCamera(
                  CameraUpdate.newCameraPosition(CameraPosition(
                    target: LatLng(_currentPosition!.latitude,
                        _currentPosition!.longitude),
                    zoom: kBaseZoom,
                  )),
                );
              }
            },
            child: const Icon(Icons.my_location,
                color: Color.fromARGB(255, 151, 86, 0)),
          ),
        ),

      // ── Level-1 check-in dialog ────────────────────────────────────────
      if (_showLevel1Dialog && _pendingLongPressPosition != null)
        Positioned.fill(
          child: GestureDetector(
            onTap: _dismissLevel1,
            child: Container(
              color: Colors.black.withValues(alpha: 0.25),
              child: CheckInLevel1Dialog(
                position:       _pendingLongPressPosition!,
                onDismiss:      _dismissLevel1,
                onCheckInSaved: _onCheckInSaved,
              ),
            ),
          ),
        ),

      // ── Check-in info panel ────────────────────────────────────────────
      if (_showInfoPanel && _selectedCheckIn != null)
        Positioned.fill(
          child: GestureDetector(
            onTap: _closeInfoPanel,
            child: Container(
              color: Colors.black.withValues(alpha: 0.25),
              child: CheckInInfoPanel(
                checkin:   _selectedCheckIn!,
                onClose:   _closeInfoPanel,
                onEdited:  _onCheckInEdited,
                onDeleted: _onCheckInDeleted,
              ),
            ),
          ),
        ),
    ]);
  }
}


// ── Shake toast widget ────────────────────────────────────────────────────────

/// Small floating notification shown after a shake check-in is saved.
/// Slides in from the top, stays for a moment, then the [OverlayEntry]
/// is removed by the caller after 2.5 seconds.
class _ShakeToast extends StatefulWidget {
  final String emoji;
  final String name;

  const _ShakeToast({required this.emoji, required this.name});

  @override
  State<_ShakeToast> createState() => _ShakeToastState();
}

class _ShakeToastState extends State<_ShakeToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);

    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 24,
      right: 24,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEE),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: const Color(0xFFFFD24B),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.emoji,
                      style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Check-in saved!',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF3D2000),
                          ),
                        ),
                        Text(
                          widget.name,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.brown[400],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    color: Color(0xFF975600),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


// ── Exploration fog painter ───────────────────────────────────────────────────

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

    final clearPaint = Paint()..blendMode = ui.BlendMode.clear;
    for (final centre in screenPositions) {
      canvas.drawCircle(centre, revealRadius, clearPaint);
      for (int i = 1; i <= 8; i++) {
        canvas.drawCircle(
          centre,
          revealRadius + (i * revealRadius * 0.06),
          Paint()
            ..blendMode  = ui.BlendMode.clear
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
            ..color      = Colors.black
                .withValues(alpha: 0.55 * (1.0 - i / 8.0)),
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(ExplorationPathPainter old) =>
      old.screenPositions != screenPositions ||
      old.revealRadius    != revealRadius;
}