// lib/services/checkin_database.dart

import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/checkin_location.dart';

class CheckInDatabase {
  static Database? _db;
  static const String _tableName = 'checkins';
  static const int _version = 1;

  /// Open (or create) the database. Safe to call multiple times.
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
            id          TEXT PRIMARY KEY,
            latitude    REAL NOT NULL,
            longitude   REAL NOT NULL,
            emoji       TEXT NOT NULL,
            label_word  TEXT,
            name        TEXT,
            details     TEXT,
            media_paths TEXT NOT NULL DEFAULT '',
            created_at  TEXT NOT NULL,
            updated_at  TEXT NOT NULL
          )
        ''');
      },
    );
  }

  // ── Path resolution ────────────────────────────────────────────────────────

  /// Resolves a list of stored filenames (or legacy absolute paths) into
  /// current absolute paths under Documents/checkin_photos/.
  ///
  /// Storing only filenames means reinstalling the app — which changes the
  /// container UUID in the absolute path — never breaks stored references.
  /// Legacy absolute paths (from before this fix) are passed through as-is
  /// so old entries degrade gracefully rather than crashing.
  static Future<List<String>> resolveMediaPaths(
      List<String> storedPaths) async {
    if (storedPaths.isEmpty) return [];
    final dir = await getApplicationDocumentsDirectory();
    final photosDir = p.join(dir.path, 'checkin_photos');
    return storedPaths.map((stored) {
      // If it already looks like an absolute path, return it unchanged.
      // This handles any entries saved before the filename-only fix.
      if (stored.startsWith('/')) return stored;
      return p.join(photosDir, stored);
    }).toList();
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  /// Insert a new check-in
  static Future<void> insert(CheckInLocation checkin) async {
    final db = await database;
    await db.insert(
      _tableName,
      checkin.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Load all check-ins
  static Future<List<CheckInLocation>> loadAll() async {
    final db = await database;
    final rows = await db.query(_tableName, orderBy: 'created_at DESC');
    return rows.map(CheckInLocation.fromMap).toList();
  }

  /// Update an existing check-in
  static Future<void> update(CheckInLocation checkin) async {
    final db = await database;
    await db.update(
      _tableName,
      checkin.toMap(),
      where: 'id = ?',
      whereArgs: [checkin.id],
    );
  }

  /// Delete a check-in by ID
  static Future<void> delete(String id) async {
    final db = await database;
    await db.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}