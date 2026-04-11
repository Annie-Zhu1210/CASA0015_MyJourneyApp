import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/friend_model.dart';

/// Manages friend relationships stored in Firestore.
/// Each user document has a `friendIds` array field.
class FriendsService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String get _uid => _auth.currentUser!.uid;

  // ── Read ─────────────────────────────────────────────────────────────────

  /// Returns the current user as a [Friend] object.
  static Future<Friend> getCurrentUserAsFriend() async {
    final snap = await _db.collection('users').doc(_uid).get();
    final data = snap.data() ?? {};
    return Friend(
      id: _uid,
      username: data['username'] as String? ?? '',
      displayName: data['displayName'] as String? ?? 'Explorer',
      avatarUrl: data['photoUrl'] as String? ?? '',
      citiesCount: (data['citiesCount'] as num?)?.toInt() ?? 0,
      countriesCount: (data['countriesCount'] as num?)?.toInt() ?? 0,
      isCurrentUser: true,
      isLocationHidden: false,
      addedAt: DateTime.now(),
    );
  }

  /// Returns all friends (current user first, then newest-added first).
  static Future<List<Friend>> getFriends() async {
    final mySnap = await _db.collection('users').doc(_uid).get();
    final myData = mySnap.data() ?? {};
    final friendIds = List<String>.from(myData['friendIds'] ?? []);

    // Build current user entry
    final me = Friend(
      id: _uid,
      username: myData['username'] as String? ?? '',
      displayName: myData['displayName'] as String? ?? 'Explorer',
      avatarUrl: myData['photoUrl'] as String? ?? '',
      citiesCount: (myData['citiesCount'] as num?)?.toInt() ?? 0,
      countriesCount: (myData['countriesCount'] as num?)?.toInt() ?? 0,
      isCurrentUser: true,
      isLocationHidden: false,
      addedAt: DateTime.fromMillisecondsSinceEpoch(0),
    );

    if (friendIds.isEmpty) return [me];

    // Fetch all friends in one batch (Firestore limit: 30 per whereIn)
    final chunks = <List<String>>[];
    for (var i = 0; i < friendIds.length; i += 30) {
      chunks.add(friendIds.sublist(
          i, i + 30 > friendIds.length ? friendIds.length : i + 30));
    }

    final List<Friend> friends = [];
    for (final chunk in chunks) {
      final snap = await _db
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        final d = doc.data();
        // Get hidden status from my hidden list
        final hiddenIds =
            List<String>.from(myData['hiddenFriendIds'] ?? []);
        friends.add(Friend(
          id: doc.id,
          username: d['username'] as String? ?? '',
          displayName: d['displayName'] as String? ?? 'Explorer',
          avatarUrl: d['photoUrl'] as String? ?? '',
          citiesCount: (d['citiesCount'] as num?)?.toInt() ?? 0,
          countriesCount: (d['countriesCount'] as num?)?.toInt() ?? 0,
          isCurrentUser: false,
          isLocationHidden: hiddenIds.contains(doc.id),
          addedAt: (d['addedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        ));
      }
    }

    // Sort friends by addedAt descending (newest first)
    friends.sort((a, b) => b.addedAt.compareTo(a.addedAt));

    return [me, ...friends];
  }

  /// Returns friend count (including current user).
  static Future<int> getFriendCount() async {
    final snap = await _db.collection('users').doc(_uid).get();
    final data = snap.data() ?? {};
    final friendIds = List<String>.from(data['friendIds'] ?? []);
    return friendIds.length + 1; // +1 for self
  }

  // ── Search ───────────────────────────────────────────────────────────────

  /// Searches for a user by username or friend code.
  /// Returns null if not found.
  static Future<Friend?> searchUser(String query) async {
    final trimmed = query.trim().toLowerCase().replaceAll('@', '');

    // Try username first
    var snap = await _db
        .collection('users')
        .where('username', isEqualTo: trimmed)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) {
      // Try friend code (case-insensitive, stored uppercase)
      snap = await _db
          .collection('users')
          .where('friendCode', isEqualTo: trimmed.toUpperCase())
          .limit(1)
          .get();
    }

    if (snap.docs.isEmpty) return null;

    final doc = snap.docs.first;
    if (doc.id == _uid) return null; // can't add yourself

    final d = doc.data();
    return Friend(
      id: doc.id,
      username: d['username'] as String? ?? '',
      displayName: d['displayName'] as String? ?? 'Explorer',
      avatarUrl: d['photoUrl'] as String? ?? '',
      citiesCount: (d['citiesCount'] as num?)?.toInt() ?? 0,
      countriesCount: (d['countriesCount'] as num?)?.toInt() ?? 0,
      isCurrentUser: false,
      isLocationHidden: false,
      addedAt: DateTime.now(),
    );
  }

  // ── Write ────────────────────────────────────────────────────────────────

  /// Adds a friend. Returns false if already friends.
  static Future<bool> addFriend(String friendId) async {
    final mySnap = await _db.collection('users').doc(_uid).get();
    final existing = List<String>.from(mySnap.data()?['friendIds'] ?? []);
    if (existing.contains(friendId)) return false;

    // Add to both sides (mutual friendship)
    final batch = _db.batch();
    batch.update(_db.collection('users').doc(_uid), {
      'friendIds': FieldValue.arrayUnion([friendId]),
    });
    batch.update(_db.collection('users').doc(friendId), {
      'friendIds': FieldValue.arrayUnion([_uid]),
    });
    await batch.commit();
    return true;
  }

  /// Removes a friend (mutual removal).
  static Future<void> removeFriend(String friendId) async {
    final batch = _db.batch();
    batch.update(_db.collection('users').doc(_uid), {
      'friendIds': FieldValue.arrayRemove([friendId]),
    });
    batch.update(_db.collection('users').doc(friendId), {
      'friendIds': FieldValue.arrayRemove([_uid]),
    });
    await batch.commit();
  }

  /// Toggles whether your location is hidden from a specific friend.
  static Future<void> toggleHideLocation(
      String friendId, bool currentlyHidden) async {
    await _db.collection('users').doc(_uid).update({
      'hiddenFriendIds': currentlyHidden
          ? FieldValue.arrayRemove([friendId])
          : FieldValue.arrayUnion([friendId]),
    });
  }
}