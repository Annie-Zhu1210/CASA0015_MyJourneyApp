class ClearableValue<T> {
  final T value;
  const ClearableValue(this.value);
}

class CheckInLocation {
  final String id;
  final double latitude;
  final double longitude;
  final String emoji;
  final String? labelWord;
  final String? name;
  final String? details;
  final List<String> mediaPaths;
  final DateTime createdAt;
  final DateTime updatedAt;

  // ── Weather fields (nullable — not all check-ins will have weather) ────────
  final String? weatherCondition; // e.g. "Partly Cloudy"
  final double? weatherTemp;      // Celsius

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
    this.weatherCondition,
    this.weatherTemp,
  }) : mediaPaths = mediaPaths ?? [];

  /// Full label shown on map bubble: emoji + optional word
  String get displayLabel =>
      labelWord != null && labelWord!.isNotEmpty ? '$emoji $labelWord' : emoji;

  /// e.g. "☀️ Sunny, 18°C" — null if no weather was recorded
  String? get weatherDisplay {
    if (weatherCondition == null || weatherTemp == null) return null;
    // Reuse WeatherData emoji logic inline to avoid a circular import
    String we = '🌡️';
    final lc = weatherCondition!.toLowerCase();
    if (lc.contains('thunderstorm')) we = '⛈️';
    else if (lc.contains('drizzle')) we = '🌦️';
    else if (lc.contains('rain')) we = '🌧️';
    else if (lc.contains('snow')) we = '❄️';
    else if (lc.contains('clear')) we = '☀️';
    else if (lc.contains('few clouds')) we = '🌤️';
    else if (lc.contains('scattered clouds')) we = '⛅';
    else if (lc.contains('cloud')) we = '☁️';
    else if (lc.contains('fog') || lc.contains('mist') || lc.contains('haze')) we = '🌫️';
    return '$we $weatherCondition, ${weatherTemp!.toStringAsFixed(0)}°C';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'latitude': latitude,
      'longitude': longitude,
      'emoji': emoji,
      'label_word': labelWord,
      'name': name,
      'details': details,
      'media_paths': mediaPaths.join('|'),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'weather_condition': weatherCondition,
      'weather_temp': weatherTemp,
    };
  }

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
      weatherCondition: map['weather_condition'] as String?,
      weatherTemp: map['weather_temp'] != null
          ? (map['weather_temp'] as num).toDouble()
          : null,
    );
  }

  CheckInLocation copyWith({
    String? emoji,
    ClearableValue<String?>? labelWord,
    ClearableValue<String?>? name,
    ClearableValue<String?>? details,
    List<String>? mediaPaths,
    DateTime? updatedAt,
    ClearableValue<String?>? weatherCondition,
    ClearableValue<double?>? weatherTemp,
  }) {
    return CheckInLocation(
      id: id,
      latitude: latitude,
      longitude: longitude,
      emoji: emoji ?? this.emoji,
      labelWord: labelWord != null ? labelWord.value : this.labelWord,
      name: name != null ? name.value : this.name,
      details: details != null ? details.value : this.details,
      mediaPaths: mediaPaths ?? this.mediaPaths,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      weatherCondition: weatherCondition != null
          ? weatherCondition.value
          : this.weatherCondition,
      weatherTemp:
          weatherTemp != null ? weatherTemp.value : this.weatherTemp,
    );
  }
}