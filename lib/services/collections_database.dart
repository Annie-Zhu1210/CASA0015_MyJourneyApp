import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/collections_model.dart';

class CollectionsDatabase {
  static Database? _db;
  static const String _tableName = 'custom_collections';
  // Bumped to 2: adds user_id column and wipes legacy unscoped data.
  static const int _version = 2;

  static String get _uid => FirebaseAuth.instance.currentUser!.uid;

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
      version: _version,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            id           TEXT PRIMARY KEY,
            user_id      TEXT NOT NULL,
            name         TEXT NOT NULL,
            location_ids TEXT NOT NULL DEFAULT '',
            created_at   TEXT NOT NULL,
            sort_order   INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Wipe unscoped legacy collections and add the required column.
          await db.execute('DELETE FROM $_tableName');
          await db.execute(
              'ALTER TABLE $_tableName ADD COLUMN user_id TEXT NOT NULL DEFAULT ""');
        }
      },
    );
  }

  static Future<void> insert(CustomCollection collection) async {
    final db = await database;
    final map = collection.toMap();
    map['user_id'] = _uid;
    await db.insert(
      _tableName,
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Returns only the collections that belong to the currently signed-in user.
  static Future<List<CustomCollection>> loadAll() async {
    final db = await database;
    final rows = await db.query(
      _tableName,
      where: 'user_id = ?',
      whereArgs: [_uid],
      orderBy: 'sort_order ASC, created_at DESC',
    );
    return rows.map(CustomCollection.fromMap).toList();
  }

  static Future<void> update(CustomCollection collection) async {
    final db = await database;
    await db.update(
      _tableName,
      collection.toMap(),
      where: 'id = ? AND user_id = ?',
      whereArgs: [collection.id, _uid],
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

  static Future<void> updateOrder(List<CustomCollection> collections) async {
    final db = await database;
    final batch = db.batch();
    for (int i = 0; i < collections.length; i++) {
      batch.update(
        _tableName,
        {'sort_order': i},
        where: 'id = ? AND user_id = ?',
        whereArgs: [collections[i].id, _uid],
      );
    }
    await batch.commit(noResult: true);
  }

  /// Deletes all collections regardless of user — used on sign-out/delete
  /// as a belt-and-suspenders cleanup since loadAll() is already scoped.
  static Future<void> deleteAll() async {
    final db = await database;
    await db.delete(_tableName);
  }
}