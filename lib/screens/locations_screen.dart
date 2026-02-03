import 'package:flutter/material.dart';

class LocationsScreen extends StatelessWidget {
  const LocationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Center(
        child: Text(
          'Locations List',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}