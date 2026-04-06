// lib/models/checkin_location.dart

class CheckInLocation {
  final String id;
  final double latitude;
  final double longitude;
  final String emoji;
  final String? labelWord;
  final String? name;
  final String? details;
  final List<String> mediaPaths; // local file paths
  final DateTime createdAt;
  final DateTime updatedAt;

  CheckInLocation({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.emoji,
    this.labelWord,
    this.name,
    this.details,
    List<String>? mediaPaths,
    required this.createdAt,
    required this.updatedAt,
  }) : mediaPaths = mediaPaths ?? [];

  /// Full label shown on map bubble: emoji + optional word
  String get displayLabel =>
      labelWord != null && labelWord!.isNotEmpty ? '$emoji $labelWord' : emoji;

  /// Convert to map for SQLite storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'latitude': latitude,
      'longitude': longitude,
      'emoji': emoji,
      'label_word': labelWord,
      'name': name,
      'details': details,
      'media_paths': mediaPaths.join('|'), // pipe-separated paths
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Reconstruct from SQLite row
  factory CheckInLocation.fromMap(Map<String, dynamic> map) {
    final rawPaths = map['media_paths'] as String? ?? '';
    return CheckInLocation(
      id: map['id'] as String,
      latitude: map['latitude'] as double,
      longitude: map['longitude'] as double,
      emoji: map['emoji'] as String,
      labelWord: map['label_word'] as String?,
      name: map['name'] as String?,
      details: map['details'] as String?,
      mediaPaths: rawPaths.isEmpty ? [] : rawPaths.split('|'),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  /// Create a copy with updated fields
  CheckInLocation copyWith({
    String? emoji,
    String? labelWord,
    String? name,
    String? details,
    List<String>? mediaPaths,
    DateTime? updatedAt,
  }) {
    return CheckInLocation(
      id: id,
      latitude: latitude,
      longitude: longitude,
      emoji: emoji ?? this.emoji,
      labelWord: labelWord ?? this.labelWord,
      name: name ?? this.name,
      details: details ?? this.details,
      mediaPaths: mediaPaths ?? this.mediaPaths,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}