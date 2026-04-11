import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProfileService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String get _uid => _auth.currentUser!.uid;

  // ── Keys for SharedPreferences ───────────────────────────────────────────
  static const _mapStyleKey = 'map_style';

  // ── Map style ────────────────────────────────────────────────────────────
  static Future<String> getMapStyle() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_mapStyleKey) ?? 'standard';
  }

  static Future<void> saveMapStyle(String style) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_mapStyleKey, style);
  }

  // ── Ensure profile exists (called after login) ───────────────────────────
  static Future<void> ensureProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final ref = _db.collection('users').doc(user.uid);
    final snap = await ref.get();

    if (!snap.exists) {
      final code = await _generateUniqueFriendCode();
      await ref.set({
        'uid': user.uid,
        'displayName': user.displayName ?? 'Explorer',
        'username': '', // empty until user sets one
        'friendCode': code,
        'email': user.email ?? '',
        'photoUrl': user.photoURL ?? '',
        'locationCount': 0,
        'citiesCount': 0,
        'friendIds': [],
        'hiddenFriendIds': [],
        'citiesCount': 0,
        'countriesCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // ── Check if user has set a username yet ─────────────────────────────────
  static Future<bool> hasUsername() async {
    final snap = await _db.collection('users').doc(_uid).get();
    if (!snap.exists) return false;
    final username = snap.data()?['username'] as String? ?? '';
    return username.trim().isNotEmpty;
  }

  // ── Get full profile ─────────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> getProfile() async {
    final snap = await _db.collection('users').doc(_uid).get();
    if (!snap.exists) return null;
    return snap.data();
  }

  // ── Update username (checks uniqueness first) ────────────────────────────
  // Returns null on success, or an error message string on failure
  static Future<String?> updateUsername(String username) async {
    final trimmed = username.trim().toLowerCase();

    if (trimmed.isEmpty) return 'Username cannot be empty';
    if (trimmed.length < 3) return 'Username must be at least 3 characters';
    if (trimmed.length > 20) return 'Username must be 20 characters or fewer';

    // Only allow letters, numbers, underscores
    final valid = RegExp(r'^[a-z0-9_]+$');
    if (!valid.hasMatch(trimmed)) {
      return 'Only letters, numbers, and underscores allowed';
    }

    // Check uniqueness
    final existing = await _db
        .collection('users')
        .where('username', isEqualTo: trimmed)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty && existing.docs.first.id != _uid) {
      return 'That username is already taken';
    }

    await _db.collection('users').doc(_uid).update({'username': trimmed});
    return null; // success
  }

  // ── Update avatar URL ────────────────────────────────────────────────────
  static Future<void> updatePhotoUrl(String url) async {
    await _db.collection('users').doc(_uid).update({'photoUrl': url});
  }

  // ── Generate a unique friend code like JOURNEY-4X8K ─────────────────────
  static Future<String> _generateUniqueFriendCode() async {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no O/0 or I/1
    final rand = Random.secure();

    while (true) {
      final suffix = List.generate(
        4,
        (_) => chars[rand.nextInt(chars.length)],
      ).join();
      final code = 'JOURNEY-$suffix';

      // Check if this code already exists
      final snap = await _db
          .collection('users')
          .where('friendCode', isEqualTo: code)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) return code; // unique — use it
      // Otherwise loop and try again
    }
  }

  // ── Update exploration counts ───────────────────────────────────────────
  static Future<void> updateExplorationCounts({
    required int citiesCount,
    required int countriesCount,
  }) async {
    try {
      await _db.collection('users').doc(_uid).update({
        'citiesCount': citiesCount,
        'countriesCount': countriesCount,
      });
    } catch (_) {
      // Silently ignore — counts will sync next time
    }
  }

  // ── Dark map style JSON ──────────────────────────────────────────────────
  static const String darkMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#212121"}]},
  {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#212121"}]},
  {"featureType":"administrative","elementType":"geometry","stylers":[{"color":"#757575"}]},
  {"featureType":"administrative.country","elementType":"labels.text.fill","stylers":[{"color":"#9e9e9e"}]},
  {"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#bdbdbd"}]},
  {"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#181818"}]},
  {"featureType":"poi.park","elementType":"labels.text.fill","stylers":[{"color":"#616161"}]},
  {"featureType":"poi.park","elementType":"labels.text.stroke","stylers":[{"color":"#1b1b1b"}]},
  {"featureType":"road","elementType":"geometry.fill","stylers":[{"color":"#2c2c2c"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#8a8a8a"}]},
  {"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#373737"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#3c3c3c"}]},
  {"featureType":"road.highway.controlled_access","elementType":"geometry","stylers":[{"color":"#4e4e4e"}]},
  {"featureType":"road.local","elementType":"labels.text.fill","stylers":[{"color":"#616161"}]},
  {"featureType":"transit","elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#000000"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#3d3d3d"}]}
]
''';
}