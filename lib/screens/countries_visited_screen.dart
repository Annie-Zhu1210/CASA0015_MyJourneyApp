
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../services/geocoding_service.dart';

class CountriesVisitedScreen extends StatelessWidget {
  final List<PlaceInfo> countries;

  const CountriesVisitedScreen({super.key, required this.countries});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      appBar: CupertinoNavigationBar(
        backgroundColor: const Color(0xFFFFF8F0),
        border: null,
        middle: const Text(
          'Countries Visited',
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
      body: countries.isEmpty
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
            CupertinoIcons.globe,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No countries yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start exploring the map\nto discover countries',
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
            color: const Color(0xFF4CAF50).withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(
                CupertinoIcons.globe,
                color: Color(0xFF4CAF50),
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                'You have explored ${countries.length} ${countries.length == 1 ? 'country' : 'countries'}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Color(0xFF2C1A00),
                ),
              ),
            ],
          ),
        ),

        // Country list
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemCount: countries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final country = countries[index];
              // Show emoji flag from country code
              final flag = _countryCodeToFlag(country.countryCode);
              return _CountryListTile(
                country: country,
                flag: flag,
              );
            },
          ),
        ),
      ],
    );
  }

  /// Converts an ISO 3166-1 alpha-2 country code to a flag emoji.
  /// e.g. "GB" → 🇬🇧
  String _countryCodeToFlag(String code) {
    if (code.length != 2) return '🌍';
    final int firstLetter = code.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final int secondLetter = code.codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCode(firstLetter) + String.fromCharCode(secondLetter);
  }
}

class _CountryListTile extends StatelessWidget {
  final PlaceInfo country;
  final String flag;

  const _CountryListTile({required this.country, required this.flag});

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
          // Flag emoji
          Text(
            flag,
            style: const TextStyle(fontSize: 30),
          ),
          const SizedBox(width: 14),
          // Country name + code
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  country.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2C1A00),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  country.countryCode,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}