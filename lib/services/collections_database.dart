// lib/services/collections_database.dart

import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/collections_model.dart';

class CollectionsDatabase {
  static Database? _db;
  static const String _tableName = 'custom_collections';

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _openDb();
    return _db!;
  }

  static Future<Database> _openDb() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'collections.db');

    return openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            id          TEXT PRIMARY KEY,
            name        TEXT NOT NULL,
            location_ids TEXT NOT NULL DEFAULT '',
            created_at  TEXT NOT NULL,
            sort_order  INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );
  }

  static Future<void> insert(CustomCollection collection) async {
    final db = await database;
    await db.insert(
      _tableName,
      collection.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Load all custom collections ordered by sort_order ascending
  static Future<List<CustomCollection>> loadAll() async {
    final db = await database;
    final rows =
        await db.query(_tableName, orderBy: 'sort_order ASC, created_at DESC');
    return rows.map(CustomCollection.fromMap).toList();
  }

  static Future<void> update(CustomCollection collection) async {
    final db = await database;
    await db.update(
      _tableName,
      collection.toMap(),
      where: 'id = ?',
      whereArgs: [collection.id],
    );
  }

  static Future<void> delete(String id) async {
    final db = await database;
    await db.delete(_tableName, where: 'id = ?', whereArgs: [id]);
  }

  /// Persist a reordered list of collections — updates sort_order for each.
  static Future<void> updateOrder(List<CustomCollection> collections) async {
    final db = await database;
    final batch = db.batch();
    for (int i = 0; i < collections.length; i++) {
      batch.update(
        _tableName,
        {'sort_order': i},
        where: 'id = ?',
        whereArgs: [collections[i].id],
      );
    }
    await batch.commit(noResult: true);
  }
}