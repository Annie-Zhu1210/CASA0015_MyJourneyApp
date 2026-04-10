// lib/screens/collection_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import '../models/checkin_location.dart';
import 'location_detail_screen.dart';

/// Generic drill-down screen shown when tapping a City or Label collection.
/// Geocodes all locations once at screen level so cards never re-geocode.
class CollectionDetailScreen extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<CheckInLocation> locations;
  final VoidCallback onChanged;

  const CollectionDetailScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.locations,
    required this.onChanged,
  });

  @override
  State<CollectionDetailScreen> createState() =>
      _CollectionDetailScreenState();
}

class _CollectionDetailScreenState extends State<CollectionDetailScreen> {
  late List<CheckInLocation> _locations;

  /// Place strings keyed by location ID. Populated once, never recomputed.
  final Map<String, String> _places = {};

  @override
  void initState() {
    super.initState();
    _locations = List.from(widget.locations);
    _geocodeAll();
  }

  Future<void> _geocodeAll() async {
    for (final loc in _locations) {
      if (!mounted) return;
      final place = await _resolvePlace(loc);
      if (mounted) setState(() => _places[loc.id] = place);
    }
  }

  static Future<String> _resolvePlace(CheckInLocation loc) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        loc.latitude,
        loc.longitude,
        localeIdentifier: 'en_US',
      );
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = <String>[
          if (p.locality?.isNotEmpty == true) p.locality!,
          if (p.country?.isNotEmpty == true) p.country!,
        ];
        if (parts.isNotEmpty) return parts.join(', ');
      }
    } catch (_) {}
    return '${loc.latitude.toStringAsFixed(4)}, '
        '${loc.longitude.toStringAsFixed(4)}';
  }

  void _openDetail(CheckInLocation checkIn) {
    Navigator.push(
      context,
      _slideRightRoute(
        LocationDetailScreen(
          checkIn: checkIn,
          onChanged: () {
            widget.onChanged();
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 1.5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFFD227).withOpacity(0.8),
                      const Color(0xFFFFD227).withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Text(
                'Hold & drag to reorder',
                style: TextStyle(
                  fontSize: 11,
                  color: const Color(0xFF3E1F00).withOpacity(0.35),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            Expanded(
              child: _locations.isEmpty
                  ? Center(
                      child: Text(
                        'No locations here yet',
                        style: TextStyle(
                          fontSize: 15,
                          color: const Color(0xFF3E1F00).withOpacity(0.4),
                        ),
                      ),
                    )
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                      onReorder: (oldIndex, newIndex) {
                        setState(() {
                          if (newIndex > oldIndex) newIndex--;
                          final item = _locations.removeAt(oldIndex);
                          _locations.insert(newIndex, item);
                        });
                      },
                      proxyDecorator: _proxyDecorator,
                      itemCount: _locations.length,
                      itemBuilder: (context, index) {
                        final loc = _locations[index];
                        return _LocationCard(
                          key: ValueKey(loc.id),
                          checkIn: loc,
                          place: _places[loc.id],
                          onTap: () => _openDetail(loc),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 20, 12),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context, _locations),
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Color(0xFF975600), size: 20),
            tooltip: 'Back',
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF3E1F00),
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  widget.subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: const Color(0xFF3E1F00).withOpacity(0.45),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _proxyDecorator(Widget child, int index, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(16),
        shadowColor: const Color(0xFFB87000).withOpacity(0.3),
        child: child,
      ),
      child: child,
    );
  }
}

// ── Location card — stateless, receives pre-resolved place string ─────────────

class _LocationCard extends StatelessWidget {
  final CheckInLocation checkIn;
  final String? place; // null = still loading
  final VoidCallback onTap;

  const _LocationCard({
    super.key,
    required this.checkIn,
    required this.place,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFB87000).withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 90,
                height: 70,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFD227),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
                child: Center(
                  child: Text(
                    checkIn.displayLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF3E1F00),
                    ),
                  ),
                ),
              ),
              Container(
                  width: 3,
                  height: 70,
                  color: const Color(0xFFFFD227).withOpacity(0.6)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        checkIn.name?.isNotEmpty == true
                            ? checkIn.name!
                            : 'Unnamed location',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: checkIn.name?.isNotEmpty == true
                              ? const Color(0xFF3E1F00)
                              : const Color(0xFF3E1F00).withOpacity(0.35),
                        ),
                      ),
                      const SizedBox(height: 3),
                      place == null
                          ? SizedBox(
                              height: 11,
                              width: 80,
                              child: LinearProgressIndicator(
                                backgroundColor:
                                    const Color(0xFFFFD6E0).withOpacity(0.4),
                                color: const Color(0xFFFFD6E0),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            )
                          : Text(
                              place!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color:
                                    const Color(0xFF3E1F00).withOpacity(0.45),
                              ),
                            ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Icon(
                  Icons.drag_handle_rounded,
                  color: const Color(0xFFB87000).withOpacity(0.35),
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Slide-from-right page route ───────────────────────────────────────────────

PageRouteBuilder<T> _slideRightRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(1.0, 0.0);
      const end = Offset.zero;
      const curve = Curves.easeInOutCubic;
      final tween =
          Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
      final secondaryTween =
          Tween(begin: Offset.zero, end: const Offset(-0.3, 0.0))
              .chain(CurveTween(curve: curve));
      return SlideTransition(
        position: secondaryAnimation.drive(secondaryTween),
        child: SlideTransition(
          position: animation.drive(tween),
          child: child,
        ),
      );
    },
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 280),
  );
}