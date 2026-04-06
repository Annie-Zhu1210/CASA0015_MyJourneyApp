// lib/widgets/checkin/checkin_level1_dialog.dart

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'checkin_editor.dart';

/// Level 1 floating window: "Add Location" or "Cancel"
/// Appears after a 2-second long press on the map.
class CheckInLevel1Dialog extends StatelessWidget {
  final LatLng position;
  final VoidCallback onDismiss;
  final VoidCallback onCheckInSaved;

  const CheckInLevel1Dialog({
    super.key,
    required this.position,
    required this.onDismiss,
    required this.onCheckInSaved,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 280,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEE), // warm cream-yellow
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pin icon
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD24B).withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.place_rounded,
                  color: Color(0xFF975600),
                  size: 28,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Save this place?',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3D2000),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Long-pressed location\nwill be saved as a check-in.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.brown[400],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 22),
              // Add Location button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    onDismiss(); // close Level 1 first
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => CheckInEditor(
                        position: position,
                        onSaved: onCheckInSaved,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD24B),
                    foregroundColor: const Color(0xFF3D2000),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: const Text(
                    'Add Location',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Cancel button
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: onDismiss,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.brown[400],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}