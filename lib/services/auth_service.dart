import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'checkin_database.dart';
import 'collections_database.dart';
import 'exploration_service.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn();
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static User? get currentUser => _auth.currentUser;
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── Sign in ───────────────────────────────────────────────────────────────

  static Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      return userCredential.user;
    } catch (e) {
      print('Google Sign-In error: $e');
      return null;
    }
  }

  // ── Sign out ──────────────────────────────────────────────────────────────

  /// Signs out and clears all local data scoped to this user so the next
  /// account starts completely fresh.
  static Future<void> signOut() async {
    await _clearLocalData();
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // ── Delete account ────────────────────────────────────────────────────────

  /// Fully deletes the account:
  /// 1. Re-authenticates with Google (Firebase requires this).
  /// 2. Deletes local SQLite check-ins for this user.
  /// 3. Deletes Firestore user doc + imported_locations subcollection.
  /// 4. Deletes the Firebase Auth account.
  /// 5. Clears all local data.
  ///
  /// Returns null on success, or an error string on failure.
  static Future<String?> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'No user signed in.';

      final uid = user.uid;

      // ── Step 1: Re-authenticate ──────────────────────────────────────────
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return 'Re-authentication cancelled.';

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await user.reauthenticateWithCredential(credential);

      // ── Step 2: Delete local SQLite check-ins ────────────────────────────
      try {
        await CheckInDatabase.deleteAllForCurrentUser();
      } catch (_) {}

      // ── Step 3: Delete Firestore data ────────────────────────────────────
      try {
        final importedSnap = await _db
            .collection('users')
            .doc(uid)
            .collection('imported_locations')
            .get();
        final batch = _db.batch();
        for (final doc in importedSnap.docs) {
          batch.delete(doc.reference);
        }
        batch.delete(_db.collection('users').doc(uid));
        await batch.commit();
      } catch (_) {}

      // ── Step 4: Delete Firebase Auth account ────────────────────────────
      await user.delete();

      // ── Step 5: Clear all local data ─────────────────────────────────────
      await _clearLocalData();
      await _googleSignIn.signOut();

      return null; // success

    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        return 'Please sign in again before deleting your account.';
      }
      return 'Delete failed: ${e.message}';
    } catch (e) {
      print('Delete account error: $e');
      return 'An unexpected error occurred. Please try again.';
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Clears all on-device data for the current user:
  /// - Exploration path (fog of war) for this uid
  /// - All custom collections
  /// - SharedPreferences (map style, geocoding cache, etc.)
  static Future<void> _clearLocalData() async {
    // Clear exploration path for this specific user before prefs are wiped
    await ExplorationService.clearForCurrentUser();
    // Clear all collections (not uid-scoped, so wipe everything)
    await CollectionsDatabase.deleteAll();
    // Clear remaining preferences (map style, geocoding cache, etc.)
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}