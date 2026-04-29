import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/checkin_location.dart';

class CheckInDatabase {
  static Database? _db;
  static const String _tableName = 'checkins';
  // Bumped to 3: adds user_id column and wipes legacy unscoped data.
  static const int _version = 3;

  // Returns the uid of the currently signed-in user.
  // Throws if called while no user is signed in (shouldn't happen in normal flow).
  static String get _uid => FirebaseAuth.instance.currentUser!.uid;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _openDb();
    return _db!;
  }

  static Future<Database> _openDb() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'checkins.db');

    return openDatabase(
      dbPath,
      version: _version,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            id                TEXT PRIMARY KEY,
            user_id           TEXT NOT NULL,
            latitude          REAL NOT NULL,
            longitude         REAL NOT NULL,
            emoji             TEXT NOT NULL,
            label_word        TEXT,
            name              TEXT,
            details           TEXT,
            media_paths       TEXT NOT NULL DEFAULT '',
            created_at        TEXT NOT NULL,
            updated_at        TEXT NOT NULL,
            weather_condition TEXT,
            weather_temp      REAL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
              'ALTER TABLE $_tableName ADD COLUMN weather_condition TEXT');
          await db.execute(
              'ALTER TABLE $_tableName ADD COLUMN weather_temp REAL');
        }
        if (oldVersion < 3) {
          // All existing rows belong to an unknown (unscoped) user.
          // Since the user confirmed they don't mind losing legacy data,
          // wipe the table and add the new required column cleanly.
          await db.execute('DELETE FROM $_tableName');
          await db.execute(
              'ALTER TABLE $_tableName ADD COLUMN user_id TEXT NOT NULL DEFAULT ""');
        }
      },
    );
  }

  // ── Path resolution ────────────────────────────────────────────────────────

  static Future<List<String>> resolveMediaPaths(
      List<String> storedPaths) async {
    if (storedPaths.isEmpty) return [];
    final dir = await getApplicationDocumentsDirectory();
    final photosDir = p.join(dir.path, 'checkin_photos');
    return storedPaths.map((stored) {
      if (stored.startsWith('/')) return stored;
      return p.join(photosDir, stored);
    }).toList();
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  static Future<void> insert(CheckInLocation checkin) async {
    final db = await database;
    final map = checkin.toMap();
    map['user_id'] = _uid; // stamp with current user
    await db.insert(
      _tableName,
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Returns only the check-ins that belong to the currently signed-in user.
  static Future<List<CheckInLocation>> loadAll() async {
    final db = await database;
    final rows = await db.query(
      _tableName,
      where: 'user_id = ?',
      whereArgs: [_uid],
      orderBy: 'created_at DESC',
    );
    return rows.map(CheckInLocation.fromMap).toList();
  }

  static Future<void> update(CheckInLocation checkin) async {
    final db = await database;
    await db.update(
      _tableName,
      checkin.toMap(),
      where: 'id = ? AND user_id = ?',
      whereArgs: [checkin.id, _uid],
    );
  }

  static Future<void> delete(String id) async {
    final db = await database;
    await db.delete(
      _tableName,
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, _uid],
    );
  }

  /// Deletes ALL check-ins for the current user.
  /// Called on account deletion so no data is left behind.
  static Future<void> deleteAllForCurrentUser() async {
    final db = await database;
    await db.delete(
      _tableName,
      where: 'user_id = ?',
      whereArgs: [_uid],
    );
  }
}