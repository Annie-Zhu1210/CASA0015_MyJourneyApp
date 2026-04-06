// lib/widgets/checkin/label_picker.dart

import 'package:flutter/material.dart';
import '../../constants/checkin_labels.dart';

/// Bottom sheet for selecting an emoji label.
/// Returns a CheckInLabel (preset) or a custom emoji string.
Future<Map<String, String>?> showLabelPicker(BuildContext context) async {
  return showModalBottomSheet<Map<String, String>>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => const _LabelPickerSheet(),
  );
}

class _LabelPickerSheet extends StatefulWidget {
  const _LabelPickerSheet();

  @override
  State<_LabelPickerSheet> createState() => _LabelPickerSheetState();
}

class _LabelPickerSheetState extends State<_LabelPickerSheet> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFFFBEE),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.brown[200],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Choose a label',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3D2000),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap a preset or pick your own emoji',
            style: TextStyle(fontSize: 13, color: Colors.brown[400]),
          ),
          const SizedBox(height: 16),

          // Preset grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.9,
            ),
            itemCount: kPresetLabels.length,
            itemBuilder: (_, i) {
              final label = kPresetLabels[i];
              final isSelected = _selectedIndex == i;
              return GestureDetector(
                onTap: () => setState(() => _selectedIndex = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFFFD24B)
                        : const Color(0xFFFFF3C4),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF975600)
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(label.emoji,
                          style: const TextStyle(fontSize: 24)),
                      const SizedBox(height: 4),
                      Text(
                        label.word,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? const Color(0xFF3D2000)
                              : Colors.brown[600],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),

          // Custom emoji button
          OutlinedButton(
            onPressed: () {
              Navigator.pop(context, {'emoji': '__custom__', 'word': ''});
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF975600),
              side: const BorderSide(color: Color(0xFFFFD24B), width: 1.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: const Text('Use my own emoji'),
          ),
          const SizedBox(height: 16),

          // Confirm button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedIndex == null
                  ? null
                  : () {
                      final label = kPresetLabels[_selectedIndex!];
                      Navigator.pop(context, {
                        'emoji': label.emoji,
                        'word': label.word,
                      });
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD24B),
                foregroundColor: const Color(0xFF3D2000),
                disabledBackgroundColor: Colors.grey[200],
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Confirm',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}