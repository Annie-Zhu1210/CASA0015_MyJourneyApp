import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../services/exploration_service.dart';
import '../services/geocoding_service.dart';
import 'cities_visited_screen.dart';
import 'countries_visited_screen.dart';

class WorldScreen extends StatefulWidget {
  const WorldScreen({super.key});

  @override
  State<WorldScreen> createState() => _WorldScreenState();
}

class _WorldScreenState extends State<WorldScreen> {
  bool _isLoading = true;
  List<PlaceInfo> _cities = [];
  List<PlaceInfo> _countries = [];
  double _worldPercent = 0.0;
  List<VisitedPoint> _visitedPoints = [];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final points = await ExplorationService.loadVisitedPoints();
      final cities = await GeocodingService.getCitiesFromPoints(points);
      final countries = await GeocodingService.getCountriesFromPoints(points);
      final percent = GeocodingService.computeWorldExploredPercent(points);

      if (mounted) {
        setState(() {
          _visitedPoints = points;
          _cities = cities;
          _countries = countries;
          _worldPercent = percent;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatWorldPercent() {
    if (_worldPercent < 0.1) return '< 0.1%';
    return '${_worldPercent.toStringAsFixed(2)}%';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'My World',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2C1A00),
                      letterSpacing: -0.5,
                    ),
                  ),
                  // Refresh button to re-geocode latest points
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _isLoading ? null : _loadStats,
                    child: const Icon(
                      CupertinoIcons.arrow_clockwise,
                      color: Color(0xFFFFCD27),
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Text(
                'Based on your exploration journey',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.brown.shade400,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),

            // ── 2×2 Stats Grid ───────────────────────────────────────────────
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CupertinoActivityIndicator(radius: 16),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          // Row 1
                          Expanded(
                            child: Row(
                              children: [
                                // Cities Visited
                                Expanded(
                                  child: _StatCard(
                                    icon: CupertinoIcons.building_2_fill,
                                    iconColor: const Color(0xFFFF8C42),
                                    title: 'Cities Visited',
                                    value: '${_cities.length}',
                                    description: _cities.isEmpty
                                        ? 'Start exploring!'
                                        : 'You have explored ${_cities.length} ${_cities.length == 1 ? 'city' : 'cities'}',
                                    onTap: () => Navigator.push(
                                      context,
                                      CupertinoPageRoute(
                                        builder: (_) => CitiesVisitedScreen(
                                          cities: _cities,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Countries Visited
                                Expanded(
                                  child: _StatCard(
                                    icon: CupertinoIcons.globe,
                                    iconColor: const Color(0xFF4CAF50),
                                    title: 'Countries Visited',
                                    value: '${_countries.length}',
                                    description: _countries.isEmpty
                                        ? 'Start exploring!'
                                        : 'You have explored ${_countries.length} ${_countries.length == 1 ? 'country' : 'countries'}',
                                    onTap: () => Navigator.push(
                                      context,
                                      CupertinoPageRoute(
                                        builder: (_) => CountriesVisitedScreen(
                                          countries: _countries,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Row 2
                          Expanded(
                            child: Row(
                              children: [
                                // World Explored %
                                Expanded(
                                  child: _StatCard(
                                    icon: CupertinoIcons.map_fill,
                                    iconColor: const Color(0xFF2196F3),
                                    title: 'World Explored',
                                    value: _formatWorldPercent(),
                                    description:
                                        'Of Earth\'s total surface area',
                                    onTap: null, // No detail screen for now
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // My Race
                                Expanded(
                                  child: _StatCard(
                                    icon: CupertinoIcons.person_2_fill,
                                    iconColor: const Color(0xFFFFCD27),
                                    title: 'My Race',
                                    value: '🏆',
                                    description:
                                        'Friend challenges coming soon',
                                    onTap: null,
                                    isComingSoon: true,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Reusable stat card widget ────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final String description;
  final VoidCallback? onTap;
  final bool isComingSoon;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.description,
    required this.onTap,
    this.isComingSoon = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.brown.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Main content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon circle
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: iconColor, size: 22),
                  ),
                  const Spacer(),
                  // Big value
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2C1A00),
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Title
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF97560A),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Description
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Tap arrow (only for tappable cards)
            if (onTap != null)
              Positioned(
                top: 12,
                right: 12,
                child: Icon(
                  CupertinoIcons.chevron_right,
                  size: 14,
                  color: Colors.grey.shade400,
                ),
              ),

            // Coming soon badge
            if (isComingSoon)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFCD27).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Soon',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF97560A),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}