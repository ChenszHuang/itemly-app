import 'dart:io';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../db/app_db.dart';
import '../models/models.dart';
import '../utils/search.dart';

/// How the product list is ordered. [orderBy] is fixed SQL, never user input.
enum SortOption {
  newest('Newest first', 'p.created_at DESC'),
  oldest('Oldest first', 'p.created_at ASC'),
  nameAsc('Name A–Z', 'p.name COLLATE NOCASE ASC, p.created_at DESC'),
  nameDesc('Name Z–A', 'p.name COLLATE NOCASE DESC, p.created_at DESC');

  const SortOption(this.label, this.orderBy);

  final String label;
  final String orderBy;
}

/// All database access goes through here. If cloud sync is added later, this
/// is the one place to extend (IDs are UUIDs and every row has timestamps).
class Repository {
  Repository._();
  static final Repository instance = Repository._();

  Database get _db => AppDb.instance.db;

  // ---------------------------------------------------------------- categories

  Future<List<Category>> categories() async {
    final rows = await _db.query('categories', orderBy: 'name COLLATE NOCASE');
    return rows
        .map((r) => Category(r['id'] as String, r['name'] as String))
        .toList();
  }

  /// Creates the category, or returns the existing one with the same name.
  Future<Category> addCategory(String rawName) async {
    final name = rawName.trim();
    final existing = await _db.query(
      'categories',
      where: 'name = ? COLLATE NOCASE',
      whereArgs: [name],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      final r = existing.first;
      return Category(r['id'] as String, r['name'] as String);
    }
    final c = Category(const Uuid().v4(), name);
    await _db.insert('categories', {
      'id': c.id,
      'name': c.name,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    return c;
  }

  // ------------------------------------------------------------------ products

  /// Ordered by [sort] (newest first by default). [query] words must ALL
  /// match somewhere in the product's searchable text or its category name.
  Future<List<Product>> list({
    String query = '',
    String? categoryId,
    bool archived = false,
    SortOption sort = SortOption.newest,
  }) async {
    final where = <String>['p.active = ?'];
    final args = <Object?>[archived ? 0 : 1];

    if (categoryId != null) {
      where.add('p.category_id = ?');
      args.add(categoryId);
    }

    const hay = "(p.search_text || ' ' || lower(coalesce(c.name, '')))";
    for (final token in SearchUtil.tokens(query)) {
      final alts = SearchUtil.expand(token);
      where.add('(${alts.map((_) => '$hay LIKE ?').join(' OR ')})');
      args.addAll(alts.map((a) => '%$a%'));
    }

    final sql =
        '''
SELECT p.*, c.name AS category_name,
  (SELECT m.file_path FROM media m
    WHERE m.product_id = p.id AND m.media_type = 'image'
    ORDER BY m.created_at, m.rowid LIMIT 1) AS thumb
FROM products p
LEFT JOIN categories c ON c.id = p.category_id
${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'}
ORDER BY ${sort.orderBy}
''';

    final rows = await _db.rawQuery(sql, args);
    return rows.map(Product.fromRow).toList();
  }

  Future<Product?> get(String id) async {
    final rows = await _db.rawQuery(
      '''
SELECT p.*, c.name AS category_name
FROM products p
LEFT JOIN categories c ON c.id = p.category_id
WHERE p.id = ?
''',
      [id],
    );
    if (rows.isEmpty) return null;

    final product = Product.fromRow(rows.first);

    final specRows = await _db.query(
      'specs',
      where: 'product_id = ?',
      whereArgs: [id],
      orderBy: 'position',
    );
    product.specs = specRows
        .map(
          (r) => Spec(
            r['attribute_name'] as String,
            r['attribute_value'] as String,
          ),
        )
        .toList();

    final mediaRows = await _db.query(
      'media',
      where: 'product_id = ?',
      whereArgs: [id],
      orderBy: 'created_at, rowid',
    );
    product.media = mediaRows
        .map(
          (r) => MediaItem(
            id: r['id'] as String,
            type: r['media_type'] == 'video'
                ? MediaType.video
                : MediaType.image,
            path: r['file_path'] as String,
            createdAt: r['created_at'] as int,
          ),
        )
        .toList();

    return product;
  }

  /// Inserts or updates the product together with its specs and media rows.
  Future<void> save(Product product) async {
    product.updatedAt = DateTime.now().millisecondsSinceEpoch;
    product.specs = product.specs
        .where((s) => s.name.trim().isNotEmpty && s.value.trim().isNotEmpty)
        .toList();

    final row = <String, Object?>{
      'id': product.id,
      'name': product.name.trim(),
      'plu': product.plu.trim(),
      'active': product.active ? 1 : 0,
      'description': product.description.trim(),
      'category_id': product.categoryId,
      'price': product.price,
      'notes': product.notes.trim(),
      'search_text': SearchUtil.build(product),
      'created_at': product.createdAt,
      'updated_at': product.updatedAt,
    };

    await _db.transaction((txn) async {
      final updated = await txn.update(
        'products',
        row,
        where: 'id = ?',
        whereArgs: [product.id],
      );
      if (updated == 0) await txn.insert('products', row);

      await txn.delete(
        'specs',
        where: 'product_id = ?',
        whereArgs: [product.id],
      );
      for (var i = 0; i < product.specs.length; i++) {
        await txn.insert('specs', {
          'id': const Uuid().v4(),
          'product_id': product.id,
          'attribute_name': product.specs[i].name.trim(),
          'attribute_value': product.specs[i].value.trim(),
          'position': i,
        });
      }

      await txn.delete(
        'media',
        where: 'product_id = ?',
        whereArgs: [product.id],
      );
      for (final m in product.media) {
        await txn.insert('media', {
          'id': m.id,
          'product_id': product.id,
          'media_type': m.type == MediaType.video ? 'video' : 'image',
          'file_path': m.path,
          'created_at': m.createdAt,
        });
      }
    });
  }

  Future<void> setActive(List<String> ids, bool active) async {
    if (ids.isEmpty) return;
    final updatedAt = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction((txn) async {
      for (var start = 0; start < ids.length; start += 500) {
        final batch = ids.skip(start).take(500).toList();
        final placeholders = List.filled(batch.length, '?').join(', ');
        await txn.update(
          'products',
          {'active': active ? 1 : 0, 'updated_at': updatedAt},
          where: 'id IN ($placeholders)',
          whereArgs: batch,
        );
      }
    });
  }

  /// Deletes the product (specs/media rows cascade) and its files on disk.
  Future<void> delete(String id) async {
    final media = await _db.query(
      'media',
      columns: ['file_path'],
      where: 'product_id = ?',
      whereArgs: [id],
    );
    await _db.delete('products', where: 'id = ?', whereArgs: [id]);
    for (final r in media) {
      await deleteFile(r['file_path'] as String);
    }
  }

  Future<void> deleteFile(String relativePath) async {
    try {
      final f = File(AppDb.instance.resolve(relativePath));
      if (await f.exists()) await f.delete();
    } catch (_) {
      // Best effort: a leftover file is harmless.
    }
  }
}
