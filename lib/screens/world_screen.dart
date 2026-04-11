import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../services/exploration_service.dart';
import '../services/user_profile_service.dart';
import '../services/geocoding_service.dart';
import '../services/friends_service.dart';
import 'cities_visited_screen.dart';
import 'countries_visited_screen.dart';
import 'friends_screen.dart';
import 'my_race_screen.dart';

class WorldScreen extends StatefulWidget {
  const WorldScreen({super.key});

  @override
  State<WorldScreen> createState() => _WorldScreenState();
}

class _WorldScreenState extends State<WorldScreen> {
  bool _isLoading = true;
  List<PlaceInfo> _cities = [];
  List<PlaceInfo> _countries = [];
  int _friendCount = 1; // at minimum just yourself

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
      final friendCount = await FriendsService.getFriendCount();

      // Sync counts to Firestore so friends leaderboard stays up to date
      await UserProfileService.updateExplorationCounts(
        citiesCount: cities.length,
        countriesCount: countries.length,
      );

      if (mounted) {
        setState(() {
          _cities = cities;
          _countries = countries;
          // Always at least 1 (yourself)
          _friendCount = friendCount < 1 ? 1 : friendCount;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Returns the current user's rank among friends by cities visited.
  /// Returns 1 if there are no other friends yet.
  int get _myRankByCities {
    // Phase 2 will populate real per-friend city counts.
    // For now, with only yourself, rank is always 1.
    return 1;
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
                                        builder: (_) =>
                                            CountriesVisitedScreen(
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
                                // ── Add Friends card ────────────────────────
                                Expanded(
                                  child: _AddFriendsCard(
                                    friendCount: _friendCount,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        CupertinoPageRoute(
                                          builder: (_) => const FriendsScreen(),
                                        ),
                                      ).then((_) => _loadStats());
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // ── My Race card ─────────────────────────────
                                Expanded(
                                  child: _MyRaceCard(
                                    rank: _myRankByCities,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        CupertinoPageRoute(
                                          builder: (_) => const MyRaceScreen(),
                                        ),
                                      );
                                    },
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

// ─── Add Friends card ─────────────────────────────────────────────────────────

class _AddFriendsCard extends StatelessWidget {
  final int friendCount;
  final VoidCallback onTap;

  const _AddFriendsCard({
    required this.friendCount,
    required this.onTap,
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
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Friends icon (replaces the old map icon)
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2196F3).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      CupertinoIcons.person_2_fill,
                      color: Color(0xFF2196F3),
                      size: 22,
                    ),
                  ),
                  const Spacer(),
                  // Friend count (big number)
                  Text(
                    '$friendCount',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2C1A00),
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Title
                  const Text(
                    'Friends',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF97560A),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Sub-description
                  Text(
                    'Add friends here.',
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
            // Tap arrow
            Positioned(
              top: 12,
              right: 12,
              child: Icon(
                CupertinoIcons.chevron_right,
                size: 14,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── My Race card ─────────────────────────────────────────────────────────────

class _MyRaceCard extends StatelessWidget {
  final int rank;
  final VoidCallback onTap;

  const _MyRaceCard({
    required this.rank,
    required this.onTap,
  });

  /// Ordinal suffix: 1st, 2nd, 3rd, 4th …
  String _ordinal(int n) {
    if (n >= 11 && n <= 13) return '${n}th';
    switch (n % 10) {
      case 1:
        return '${n}st';
      case 2:
        return '${n}nd';
      case 3:
        return '${n}rd';
      default:
        return '${n}th';
    }
  }

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
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Trophy / crown icon (replaces old person_2_fill)
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFCD27).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      CupertinoIcons.rosette, // crown/trophy style
                      color: Color(0xFFFFCD27),
                      size: 22,
                    ),
                  ),
                  const Spacer(),
                  // Rank number (replaces trophy emoji)
                  Text(
                    _ordinal(rank),
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2C1A00),
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Title
                  const Text(
                    'My Race',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF97560A),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Description: cities ranking context
                  Text(
                    'Cities visited ranking',
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
            // Tap arrow
            Positioned(
              top: 12,
              right: 12,
              child: Icon(
                CupertinoIcons.chevron_right,
                size: 14,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Generic reusable stat card ───────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final String description;
  final VoidCallback? onTap;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.description,
    required this.onTap,
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
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
          ],
        ),
      ),
    );
  }
}