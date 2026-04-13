import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/user_profile_service.dart';

/// A single post on the public noticeboard.
class NoticeboardPost {
  final String id;
  final String userId;
  final String username;
  final String emoji;
  final String? labelWord;
  final String? locationName;
  final String? details;
  final String? city;
  final double latitude;
  final double longitude;
  final DateTime sharedAt;

  const NoticeboardPost({
    required this.id,
    required this.userId,
    required this.username,
    required this.emoji,
    this.labelWord,
    this.locationName,
    this.details,
    this.city,
    required this.latitude,
    required this.longitude,
    required this.sharedAt,
  });

  /// Display label: emoji + optional word, matching CheckInLocation.displayLabel
  String get displayLabel =>
      labelWord != null && labelWord!.isNotEmpty ? '$emoji $labelWord' : emoji;

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'username': username,
        'emoji': emoji,
        'labelWord': labelWord,
        'locationName': locationName,
        'details': details,
        'city': city,
        'latitude': latitude,
        'longitude': longitude,
        'sharedAt': FieldValue.serverTimestamp(),
      };

  factory NoticeboardPost.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NoticeboardPost(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      username: data['username'] as String? ?? 'Unknown',
      emoji: data['emoji'] as String? ?? '📍',
      labelWord: data['labelWord'] as String?,
      locationName: data['locationName'] as String?,
      details: data['details'] as String?,
      city: data['city'] as String?,
      latitude: (data['latitude'] as num).toDouble(),
      longitude: (data['longitude'] as num).toDouble(),
      sharedAt: data['sharedAt'] != null
          ? (data['sharedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}

class NoticeboardService {
  static final _db = FirebaseFirestore.instance;
  static const _collection = 'noticeboard';

  /// Post a location to the public noticeboard.
  /// Returns null on success, or an error string on failure.
  static Future<String?> postLocation({
    required String emoji,
    String? labelWord,
    String? locationName,
    String? details,
    String? city,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return 'You must be signed in to share.';

      final profile = await UserProfileService.getProfile();
      final username = (profile?['username'] as String?)?.isNotEmpty == true
          ? profile!['username'] as String
          : user.displayName ?? 'Explorer';

      final post = NoticeboardPost(
        id: '',
        userId: user.uid,
        username: username,
        emoji: emoji,
        labelWord: labelWord,
        locationName: locationName,
        details: details,
        city: city,
        latitude: latitude,
        longitude: longitude,
        sharedAt: DateTime.now(),
      );

      await _db.collection(_collection).add(post.toMap());
      return null; // success
    } catch (e) {
      return 'Failed to share: $e';
    }
  }

  /// Fetch the latest [limit] posts from the noticeboard, newest first.
  static Future<List<NoticeboardPost>> fetchFeed({int limit = 30}) async {
    try {
      final snapshot = await _db
          .collection(_collection)
          .orderBy('sharedAt', descending: true)
          .limit(limit)
          .get();
      return snapshot.docs.map(NoticeboardPost.fromDoc).toList();
    } catch (e) {
      return [];
    }
  }

  /// Stream version — for real-time updates on the World screen feed.
  static Stream<List<NoticeboardPost>> feedStream({int limit = 30}) {
    return _db
        .collection(_collection)
        .orderBy('sharedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(NoticeboardPost.fromDoc).toList());
  }

  /// Delete a post (only the owner can do this — enforced by Firestore rules).
  static Future<void> deletePost(String postId) async {
    await _db.collection(_collection).doc(postId).delete();
  }
  /// Returns true if the current user is the author of this post.
  static Future<bool> isCurrentUserPost(NoticeboardPost post) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    return post.userId == user.uid;
  }

  /// Import a noticeboard post into the user's own "From Friends" list.
  /// Saves it to a subcollection under the user's Firestore profile.
  static Future<void> importPost(NoticeboardPost post) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not signed in');

    await _db
        .collection('users')
        .doc(user.uid)
        .collection('imported_locations')
        .doc(post.id)
        .set({
      'postId': post.id,
      'userId': post.userId,
      'username': post.username,
      'emoji': post.emoji,
      'labelWord': post.labelWord,
      'locationName': post.locationName,
      'details': post.details,
      'city': post.city,
      'latitude': post.latitude,
      'longitude': post.longitude,
      'importedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Fetch all locations the current user has imported from the noticeboard.
  static Future<List<NoticeboardPost>> fetchImported() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final snapshot = await _db
          .collection('users')
          .doc(user.uid)
          .collection('imported_locations')
          .orderBy('importedAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return NoticeboardPost(
          id: data['postId'] as String? ?? doc.id,
          userId: data['userId'] as String? ?? '',
          username: data['username'] as String? ?? 'Unknown',
          emoji: data['emoji'] as String? ?? '📍',
          labelWord: data['labelWord'] as String?,
          locationName: data['locationName'] as String?,
          details: data['details'] as String?,
          city: data['city'] as String?,
          latitude: (data['latitude'] as num).toDouble(),
          longitude: (data['longitude'] as num).toDouble(),
          sharedAt: data['importedAt'] != null
              ? (data['importedAt'] as Timestamp).toDate()
              : DateTime.now(),
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Stream version of imported locations — for real-time updates
  /// on the "From Friends" tab in the Locations screen.
  static Stream<List<NoticeboardPost>> importedStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value([]);

    return _db
        .collection('users')
        .doc(user.uid)
        .collection('imported_locations')
        .orderBy('importedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = doc.data();
              return NoticeboardPost(
                id: data['postId'] as String? ?? doc.id,
                userId: data['userId'] as String? ?? '',
                username: data['username'] as String? ?? 'Unknown',
                emoji: data['emoji'] as String? ?? '📍',
                labelWord: data['labelWord'] as String?,
                locationName: data['locationName'] as String?,
                details: data['details'] as String?,
                city: data['city'] as String?,
                latitude: (data['latitude'] as num).toDouble(),
                longitude: (data['longitude'] as num).toDouble(),
                sharedAt: data['importedAt'] != null
                    ? (data['importedAt'] as Timestamp).toDate()
                    : DateTime.now(),
              );
            }).toList());
    
  }
}