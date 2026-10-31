import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Owns the SQLite database and the private folder where media is stored.
///
/// Android:
/// Database and media are stored in the app's private directory.
///
/// Web:
/// Database is stored using IndexedDB through sqflite_common_ffi_web.
class AppDb {
  AppDb._();

  static final AppDb instance = AppDb._();

  late final Database db;
  late final String _root;

  Future<void> init() async {
    String dbPath;

    if (kIsWeb) {
      // WEB: Initialize SQLite Web
      databaseFactory = databaseFactoryFfiWeb;

      _root = '';
      dbPath = 'catalog_web.db';
    } else {
      // ANDROID: Keep existing database and media location
      final docs = await getApplicationDocumentsDirectory();

      _root = docs.path;

      await Directory(p.join(_root, 'media')).create(recursive: true);

      dbPath = p.join(await getDatabasesPath(), 'catalog.db');
    }

    db = await openDatabase(
      dbPath,
      version: 3,

      onConfigure: (d) async {
        await d.execute('PRAGMA foreign_keys = ON');
      },

      onCreate: (d, version) async {
        await d.execute('''
CREATE TABLE categories (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL UNIQUE COLLATE NOCASE,
  created_at INTEGER NOT NULL
)''');

        await d.execute('''
CREATE TABLE products (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  plu TEXT NOT NULL DEFAULT '',
  active INTEGER NOT NULL DEFAULT 1,
  description TEXT NOT NULL DEFAULT '',
  category_id TEXT REFERENCES categories(id) ON DELETE SET NULL,
  price INTEGER,
  notes TEXT NOT NULL DEFAULT '',
  search_text TEXT NOT NULL DEFAULT '',
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
)''');

        await d.execute('''
CREATE TABLE specs (
  id TEXT PRIMARY KEY,
  product_id TEXT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  attribute_name TEXT NOT NULL,
  attribute_value TEXT NOT NULL,
  position INTEGER NOT NULL DEFAULT 0
)''');

        await d.execute('''
CREATE TABLE media (
  id TEXT PRIMARY KEY,
  product_id TEXT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  media_type TEXT NOT NULL,
  file_path TEXT NOT NULL,
  created_at INTEGER NOT NULL
)''');

        await d.execute('CREATE INDEX idx_specs_product ON specs(product_id)');

        await d.execute('CREATE INDEX idx_media_product ON media(product_id)');

        await d.execute(
          'CREATE INDEX idx_products_created ON products(created_at)',
        );
      },

      onUpgrade: (d, oldVersion, newVersion) async {
        final columns = await d.rawQuery('PRAGMA table_info(products)');

        final columnNames = columns.map((column) => column['name']).toSet();

        if (oldVersion < 2 && !columnNames.contains('plu')) {
          await d.execute(
            "ALTER TABLE products ADD COLUMN plu TEXT NOT NULL DEFAULT ''",
          );
        }

        if (oldVersion < 3 && !columnNames.contains('active')) {
          await d.execute(
            'ALTER TABLE products ADD COLUMN active INTEGER NOT NULL DEFAULT 1',
          );
        }
      },
    );
  }

  /// Turns a stored relative path into an absolute file path.
  String resolve(String relative) {
    if (kIsWeb) return relative;
    return p.join(_root, relative);
  }
}
