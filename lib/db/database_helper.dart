import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/clothing_item.dart';
import '../models/outfit.dart';
import '../models/outfit_history.dart';

class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, 'wardrobe_ai.db');

    return openDatabase(
      path,
      version: 3,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            "ALTER TABLE clothes ADD COLUMN gender TEXT NOT NULL DEFAULT 'unisex'",
          );
        }
        if (oldVersion < 3) {
          await db.execute(
            'ALTER TABLE clothes ADD COLUMN archived INTEGER NOT NULL DEFAULT 0',
          );
          await db.execute('''
            CREATE TABLE extra_photos (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              item_id INTEGER NOT NULL,
              image_path TEXT NOT NULL,
              FOREIGN KEY (item_id) REFERENCES clothes (id) ON DELETE CASCADE
            )
          ''');
        }
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE clothes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            category TEXT NOT NULL,
            image_path TEXT NOT NULL,
            colour TEXT NOT NULL,
            pattern TEXT NOT NULL,
            sleeve_length TEXT,
            season TEXT NOT NULL,
            style TEXT NOT NULL,
            gender TEXT NOT NULL DEFAULT 'unisex',
            brand TEXT,
            favourite INTEGER NOT NULL DEFAULT 0,
            archived INTEGER NOT NULL DEFAULT 0,
            date_added TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE extra_photos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            item_id INTEGER NOT NULL,
            image_path TEXT NOT NULL,
            FOREIGN KEY (item_id) REFERENCES clothes (id) ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE TABLE outfits (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            top_id INTEGER NOT NULL,
            bottom_id INTEGER,
            shoe_id INTEGER,
            accessory_id INTEGER,
            occasion TEXT NOT NULL,
            favourite INTEGER NOT NULL DEFAULT 0,
            date_created TEXT NOT NULL,
            FOREIGN KEY (top_id) REFERENCES clothes (id) ON DELETE CASCADE,
            FOREIGN KEY (bottom_id) REFERENCES clothes (id) ON DELETE SET NULL,
            FOREIGN KEY (shoe_id) REFERENCES clothes (id) ON DELETE SET NULL,
            FOREIGN KEY (accessory_id) REFERENCES clothes (id) ON DELETE SET NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            outfit_id INTEGER NOT NULL,
            date TEXT NOT NULL,
            FOREIGN KEY (outfit_id) REFERENCES outfits (id) ON DELETE CASCADE
          )
        ''');
      },
    );
  }

  // ---- Clothes ----

  Future<int> insertClothingItem(ClothingItem item) async {
    final db = await database;
    return db.insert('clothes', item.toMap()..remove('id'));
  }

  Future<int> updateClothingItem(ClothingItem item) async {
    final db = await database;
    return db.update(
      'clothes',
      item.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> deleteClothingItem(int id) async {
    final db = await database;
    return db.delete('clothes', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<ClothingItem>> getAllClothingItems({bool includeArchived = false}) async {
    final db = await database;
    final rows = await db.query(
      'clothes',
      where: includeArchived ? null : 'archived = 0',
      orderBy: 'date_added DESC',
    );
    return rows.map(ClothingItem.fromMap).toList();
  }

  Future<List<ClothingItem>> getArchivedClothingItems() async {
    final db = await database;
    final rows = await db.query(
      'clothes',
      where: 'archived = 1',
      orderBy: 'date_added DESC',
    );
    return rows.map(ClothingItem.fromMap).toList();
  }

  Future<List<ClothingItem>> getClothingItemsByCategory(
    String categoryKey, {
    bool includeArchived = false,
  }) async {
    final db = await database;
    final rows = await db.query(
      'clothes',
      where: includeArchived ? 'category = ?' : 'category = ? AND archived = 0',
      whereArgs: [categoryKey],
      orderBy: 'date_added DESC',
    );
    return rows.map(ClothingItem.fromMap).toList();
  }

  Future<List<ClothingItem>> getClothingItemsByIds(List<int> ids) async {
    if (ids.isEmpty) return [];
    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(',');
    final rows = await db.query(
      'clothes',
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
    return rows.map(ClothingItem.fromMap).toList();
  }

  Future<List<ClothingItem>> searchClothingItems(String query) async {
    final db = await database;
    final like = '%$query%';
    final rows = await db.query(
      'clothes',
      where: '(colour LIKE ? OR pattern LIKE ? OR brand LIKE ? OR category LIKE ? OR gender LIKE ?) '
          'AND archived = 0',
      whereArgs: [like, like, like, like, like],
      orderBy: 'date_added DESC',
    );
    return rows.map(ClothingItem.fromMap).toList();
  }

  /// Simple duplicate check for the upload flow: same category, same colour
  /// and pattern (case-insensitive), not archived.
  Future<bool> hasSimilarClothingItem({
    required String categoryKey,
    required String colour,
    required String pattern,
  }) async {
    final db = await database;
    final rows = await db.query(
      'clothes',
      where: 'category = ? AND archived = 0 AND LOWER(colour) = ? AND LOWER(pattern) = ?',
      whereArgs: [categoryKey, colour.toLowerCase().trim(), pattern.toLowerCase().trim()],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  // ---- Extra photos ----

  Future<int> addExtraPhoto(int itemId, String imagePath) async {
    final db = await database;
    return db.insert('extra_photos', {'item_id': itemId, 'image_path': imagePath});
  }

  Future<List<String>> getExtraPhotos(int itemId) async {
    final db = await database;
    final rows = await db.query(
      'extra_photos',
      where: 'item_id = ?',
      whereArgs: [itemId],
    );
    return rows.map((r) => r['image_path'] as String).toList();
  }

  Future<void> deleteExtraPhoto(int photoRowId) async {
    final db = await database;
    await db.delete('extra_photos', where: 'id = ?', whereArgs: [photoRowId]);
  }

  Future<List<Map<String, Object?>>> getExtraPhotoRows(int itemId) async {
    final db = await database;
    return db.query('extra_photos', where: 'item_id = ?', whereArgs: [itemId]);
  }

  // ---- Outfits ----

  Future<int> insertOutfit(Outfit outfit) async {
    final db = await database;
    return db.insert('outfits', outfit.toMap()..remove('id'));
  }

  Future<int> updateOutfit(Outfit outfit) async {
    final db = await database;
    return db.update(
      'outfits',
      outfit.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [outfit.id],
    );
  }

  Future<int> deleteOutfit(int id) async {
    final db = await database;
    return db.delete('outfits', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Outfit>> getFavouriteOutfits() async {
    final db = await database;
    final rows = await db.query(
      'outfits',
      where: 'favourite = 1',
      orderBy: 'date_created DESC',
    );
    return rows.map(Outfit.fromMap).toList();
  }

  Future<List<Outfit>> getAllOutfits() async {
    final db = await database;
    final rows = await db.query('outfits', orderBy: 'date_created DESC');
    return rows.map(Outfit.fromMap).toList();
  }

  Future<Outfit?> getOutfitById(int id) async {
    final db = await database;
    final rows = await db.query('outfits', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Outfit.fromMap(rows.first);
  }

  // ---- History ----

  Future<int> insertHistoryEntry(OutfitHistoryEntry entry) async {
    final db = await database;
    return db.insert('history', entry.toMap()..remove('id'));
  }

  /// Outfit ids worn within the last [days] days, most recent first.
  Future<List<int>> getRecentlyWornOutfitIds({int days = 14}) async {
    final db = await database;
    final since = DateTime.now().subtract(Duration(days: days)).toIso8601String();
    final rows = await db.query(
      'history',
      where: 'date >= ?',
      whereArgs: [since],
      orderBy: 'date DESC',
    );
    return rows.map((r) => r['outfit_id'] as int).toSet().toList();
  }

  Future<List<OutfitHistoryEntry>> getHistory() async {
    final db = await database;
    final rows = await db.query('history', orderBy: 'date DESC');
    return rows.map(OutfitHistoryEntry.fromMap).toList();
  }

  /// How many times each clothing item has appeared in a worn outfit,
  /// keyed by clothing item id.
  Future<Map<int, int>> getItemWearCounts() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT item_id, COUNT(*) AS wear_count FROM (
        SELECT o.top_id AS item_id FROM history h JOIN outfits o ON h.outfit_id = o.id
        UNION ALL
        SELECT o.bottom_id AS item_id FROM history h JOIN outfits o ON h.outfit_id = o.id
          WHERE o.bottom_id IS NOT NULL
        UNION ALL
        SELECT o.shoe_id AS item_id FROM history h JOIN outfits o ON h.outfit_id = o.id
          WHERE o.shoe_id IS NOT NULL
        UNION ALL
        SELECT o.accessory_id AS item_id FROM history h JOIN outfits o ON h.outfit_id = o.id
          WHERE o.accessory_id IS NOT NULL
      )
      GROUP BY item_id
      ORDER BY wear_count DESC
    ''');
    return {for (final r in rows) r['item_id'] as int: r['wear_count'] as int};
  }
}
