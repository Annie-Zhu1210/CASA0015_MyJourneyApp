// lib/constants/checkin_labels.dart

class CheckInLabel {
  final String emoji;
  final String word;

  const CheckInLabel({required this.emoji, required this.word});
}

const List<CheckInLabel> kPresetLabels = [
  CheckInLabel(emoji: '❤️', word: 'Favourite'),
  CheckInLabel(emoji: '🍜', word: 'Food'),
  CheckInLabel(emoji: '☕', word: 'Café'),
  CheckInLabel(emoji: '🍺', word: 'Bar'),
  CheckInLabel(emoji: '🏛️', word: 'Attraction'),
  CheckInLabel(emoji: '🛍️', word: 'Shopping'),
  CheckInLabel(emoji: '🌿', word: 'Nature'),
  CheckInLabel(emoji: '🎵', word: 'Music'),
  CheckInLabel(emoji: '🎨', word: 'Art'),
  CheckInLabel(emoji: '🏨', word: 'Hotel'),
  CheckInLabel(emoji: '📚', word: 'Study'),
  CheckInLabel(emoji: '🏋️', word: 'Gym'),
];