// lib/models/collections_model.dart

/// Represents a user-created custom collection in "My Collections".
class CustomCollection {
  final String id;
  final String name; // can be text or emoji, max 30 chars
  final List<String> locationIds; // ordered list of CheckInLocation IDs
  final DateTime createdAt;
  final int sortOrder; // lower = higher in list (user-dragged order)

  const CustomCollection({
    required this.id,
    required this.name,
    required this.locationIds,
    required this.createdAt,
    required this.sortOrder,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'location_ids': locationIds.join('|'),
        'created_at': createdAt.toIso8601String(),
        'sort_order': sortOrder,
      };

  factory CustomCollection.fromMap(Map<String, dynamic> map) =>
      CustomCollection(
        id: map['id'] as String,
        name: map['name'] as String,
        locationIds: (map['location_ids'] as String).isEmpty
            ? []
            : (map['location_ids'] as String).split('|'),
        createdAt: DateTime.parse(map['created_at'] as String),
        sortOrder: map['sort_order'] as int,
      );

  CustomCollection copyWith({
    String? name,
    List<String>? locationIds,
    int? sortOrder,
  }) =>
      CustomCollection(
        id: id,
        name: name ?? this.name,
        locationIds: locationIds ?? this.locationIds,
        createdAt: createdAt,
        sortOrder: sortOrder ?? this.sortOrder,
      );
}