import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Center(
        child: Text(
          'Settings',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}