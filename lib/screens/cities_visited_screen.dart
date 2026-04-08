import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../services/geocoding_service.dart';

class CitiesVisitedScreen extends StatelessWidget {
  final List<PlaceInfo> cities;

  const CitiesVisitedScreen({super.key, required this.cities});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      appBar: CupertinoNavigationBar(
        backgroundColor: const Color(0xFFFFF8F0),
        border: null,
        middle: const Text(
          'Cities Visited',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF2C1A00),
          ),
        ),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context),
          child: const Icon(
            CupertinoIcons.back,
            color: Color(0xFFFFCD27),
          ),
        ),
      ),
      body: cities.isEmpty
          ? _buildEmpty(context)
          : _buildList(context),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.building_2_fill,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No cities yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start exploring the map\nto discover cities',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade400,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    return Column(
      children: [
        // Summary banner
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFF8C42).withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(
                CupertinoIcons.building_2_fill,
                color: Color(0xFFFF8C42),
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                'You have explored ${cities.length} ${cities.length == 1 ? 'city' : 'cities'}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Color(0xFF2C1A00),
                ),
              ),
            ],
          ),
        ),

        // City list
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemCount: cities.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final city = cities[index];
              return _PlaceListTile(
                place: city,
                icon: CupertinoIcons.building_2_fill,
                iconColor: const Color(0xFFFF8C42),
                subtitle: city.countryCode,
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Shared tile widget (used by both screens) ────────────────────────────────

class _PlaceListTile extends StatelessWidget {
  final PlaceInfo place;
  final IconData icon;
  final Color iconColor;
  final String subtitle;

  const _PlaceListTile({
    required this.place,
    required this.icon,
    required this.iconColor,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.brown.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 14),
          // Name + subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2C1A00),
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Coordinates hint
          Text(
            '${place.latitude.toStringAsFixed(2)}°, ${place.longitude.toStringAsFixed(2)}°',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }
}