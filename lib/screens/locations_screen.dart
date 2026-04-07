// lib/screens/locations_screen.dart

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import '../models/checkin_location.dart';
import 'location_detail_screen.dart';

class LocationsScreen extends StatelessWidget {
  final List<CheckInLocation> checkIns;
  final VoidCallback onChanged;

  const LocationsScreen({
    super.key,
    this.checkIns = const [],
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFF8F0),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  const Text(
                    'My Locations',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF3E1F00),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Spacer(),
                  if (checkIns.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD227),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${checkIns.length}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF3E1F00),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Divider ──────────────────────────────────────────────────
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

            const SizedBox(height: 8),

            // ── List or empty state ───────────────────────────────────────
            Expanded(
              child: checkIns.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: checkIns.length,
                      itemBuilder: (context, index) {
                        return _LocationCard(
                          checkIn: checkIns[index],
                          onChanged: onChanged,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFFFD227).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.add_location_alt_outlined,
              size: 36,
              color: Color(0xFFB87000),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No locations yet',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Color(0xFF3E1F00),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Long-press on the map to\nadd your first check-in',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: const Color(0xFF3E1F00).withOpacity(0.5),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Location card ─────────────────────────────────────────────────────────────

class _LocationCard extends StatefulWidget {
  final CheckInLocation checkIn;
  final VoidCallback onChanged;

  const _LocationCard({required this.checkIn, required this.onChanged});

  @override
  State<_LocationCard> createState() => _LocationCardState();
}

class _LocationCardState extends State<_LocationCard> {
  String _place = '';
  bool _loadingPlace = true;

  @override
  void initState() {
    super.initState();
    _fetchPlace();
  }

  Future<void> _fetchPlace() async {
    try {
      final placemarks = await placemarkFromCoordinates(
        widget.checkIn.latitude,
        widget.checkIn.longitude,
      );
      if (placemarks.isNotEmpty && mounted) {
        final p = placemarks.first;
        final parts = <String>[
          if (p.locality != null && p.locality!.isNotEmpty) p.locality!,
          if (p.country != null && p.country!.isNotEmpty) p.country!,
        ];
        setState(() {
          _place = parts.join(', ');
          _loadingPlace = false;
        });
      } else {
        _setFallback();
      }
    } catch (_) {
      _setFallback();
    }
  }

  void _setFallback() {
    if (!mounted) return;
    setState(() {
      _place = '${widget.checkIn.latitude.toStringAsFixed(4)}, '
          '${widget.checkIn.longitude.toStringAsFixed(4)}';
      _loadingPlace = false;
    });
  }

  void _openDetail() {
    Navigator.push(
      context,
      _slideRightRoute(
        LocationDetailScreen(
          checkIn: widget.checkIn,
          onChanged: widget.onChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: GestureDetector(
        onTap: _openDetail,
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
              // ── Label pill ──────────────────────────────────────────────
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
                    widget.checkIn.displayLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF3E1F00),
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              ),

              // ── Divider accent ───────────────────────────────────────────
              Container(
                width: 3,
                height: 70,
                color: const Color(0xFFFFD227).withOpacity(0.4),
              ),

              // ── Name + place ─────────────────────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name
                      Text(
                        widget.checkIn.name?.isNotEmpty == true
                            ? widget.checkIn.name!
                            : 'Unnamed location',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: widget.checkIn.name?.isNotEmpty == true
                              ? const Color(0xFF3E1F00)
                              : const Color(0xFF3E1F00).withOpacity(0.35),
                          letterSpacing: -0.1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      // City, Country (or coords as fallback)
                      _loadingPlace
                          ? SizedBox(
                              height: 11,
                              width: 80,
                              child: LinearProgressIndicator(
                                backgroundColor:
                                    const Color(0xFFFFD227).withOpacity(0.2),
                                color: const Color(0xFFFFD227),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            )
                          : Text(
                              _place,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: const Color(0xFF3E1F00).withOpacity(0.45),
                              ),
                            ),
                    ],
                  ),
                ),
              ),

              // ── Chevron ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: const Color(0xFFB87000).withOpacity(0.4),
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

PageRouteBuilder _slideRightRoute(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // Detail slides in from the right; list slides out to the left on push,
      // and slides back in from the left on pop (Flutter handles the reverse
      // automatically when the secondary animation drives the list).
      const begin = Offset(1.0, 0.0);
      const end = Offset.zero;
      const curve = Curves.easeInOutCubic;

      final tween =
          Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
      final offsetAnimation = animation.drive(tween);

      // Outgoing screen (list) slides left
      final secondaryTween =
          Tween(begin: Offset.zero, end: const Offset(-0.3, 0.0))
              .chain(CurveTween(curve: curve));
      final secondaryOffset = secondaryAnimation.drive(secondaryTween);

      return SlideTransition(
        position: secondaryOffset,
        child: SlideTransition(
          position: offsetAnimation,
          child: child,
        ),
      );
    },
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 280),
  );
}