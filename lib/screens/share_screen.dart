import 'package:flutter/material.dart';

class ShareScreen extends StatelessWidget {
  const ShareScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Center(
        child: Text(
          'Share Screen',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}