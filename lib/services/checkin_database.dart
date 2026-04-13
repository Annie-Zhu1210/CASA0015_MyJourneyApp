import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/checkin_location.dart';

class CheckInDatabase {
  static Database? _db;
  static const String _tableName = 'checkins';
  // ↑ Bumped from 1 → 2 to trigger onUpgrade and add the weather columns.
  static const int _version = 2;

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
          // Add weather columns to existing databases — existing rows will
          // have NULL for both columns, which is handled gracefully.
          await db.execute(
              'ALTER TABLE $_tableName ADD COLUMN weather_condition TEXT');
          await db.execute(
              'ALTER TABLE $_tableName ADD COLUMN weather_temp REAL');
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
    await db.insert(
      _tableName,
      checkin.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<CheckInLocation>> loadAll() async {
    final db = await database;
    final rows = await db.query(_tableName, orderBy: 'created_at DESC');
    return rows.map(CheckInLocation.fromMap).toList();
  }

  static Future<void> update(CheckInLocation checkin) async {
    final db = await database;
    await db.update(
      _tableName,
      checkin.toMap(),
      where: 'id = ?',
      whereArgs: [checkin.id],
    );
  }

  static Future<void> delete(String id) async {
    final db = await database;
    await db.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}