import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' hide DatabaseException;

import 'package:disaster/core/errors/exceptions.dart';

/// SQLite database for the Offline-First architecture.
///
/// Schema, migrations and indexes live here. All data access goes through
/// repositories — nothing else touches SQL directly.
class AppDatabase {
  AppDatabase._(this._db);

  static const String dbName = 'disaster_alert.db';
  static const int schemaVersion = 2;

  final Database _db;
  Database get db => _db;

  bool get isOpen => _db.isOpen;

  /// Opens (creating/migrating) the database.
  ///
  /// [factory] can be swapped for `databaseFactoryFfi` in tests.
  static Future<AppDatabase> open({
    String? path,
    DatabaseFactory? factory,
  }) async {
    try {
      final f = factory ??
    (kIsWeb ? databaseFactoryFfiWeb : databaseFactory);

final dbPath = path ??
    (kIsWeb ? dbName : await _defaultPath(f));
      final db = await f.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: schemaVersion,
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON');
          },
          onCreate: _createSchema,
          onUpgrade: _upgrade,
        ),
      );
      return AppDatabase._(db);
    } catch (e) {
      throw DatabaseException('Failed to open database', cause: e);
    }
  }

  static Future<String> _defaultPath(DatabaseFactory f) async {
    try {
      final dir = await f.getDatabasesPath();
      return p.join(dir, dbName);
    } catch (_) {
      return dbName;
    }
  }

  static Future<void> _createSchema(Database db, int version) async {
    final batch = db.batch();

    // users
    batch.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        name TEXT,
        device_id TEXT,
        is_registered INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER,
        updated_at INTEGER
      )
    ''');
    batch.execute('CREATE INDEX idx_users_device ON users(device_id)');

    // disasters
    batch.execute('''
      CREATE TABLE disasters (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        affected_radius_km REAL NOT NULL DEFAULT 0,
        severity TEXT NOT NULL DEFAULT 'info',
        magnitude REAL,
        status TEXT NOT NULL DEFAULT 'active',
        occurred_at INTEGER,
        expires_at INTEGER,
        created_at INTEGER,
        updated_at INTEGER,
        source TEXT,
        provider TEXT NOT NULL DEFAULT 'server',
        payload_hash TEXT,
        instructions TEXT,
        area TEXT,
        external_url TEXT
      )
    ''');
    batch.execute('CREATE INDEX idx_disasters_provider ON disasters(provider)');
    batch.execute('CREATE INDEX idx_disasters_status ON disasters(status)');
    batch.execute(
      'CREATE INDEX idx_disasters_geo ON disasters(latitude, longitude)',
    );
    batch.execute(
      'CREATE INDEX idx_disasters_expires ON disasters(expires_at)',
    );

    // emergency_contacts
    batch.execute('''
      CREATE TABLE emergency_contacts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        relationship TEXT,
        is_primary INTEGER NOT NULL DEFAULT 0,
        is_verified INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER
      )
    ''');
    batch.execute(
      'CREATE INDEX idx_contacts_primary ON emergency_contacts(is_primary)',
    );

    // shelters
    batch.execute('''
      CREATE TABLE shelters (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        address TEXT,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        phone TEXT,
        type TEXT NOT NULL DEFAULT 'shelter',
        capacity INTEGER,
        is_open INTEGER NOT NULL DEFAULT 1,
        source TEXT
      )
    ''');
    batch.execute('CREATE INDEX idx_shelters_type ON shelters(type)');
    batch.execute(
      'CREATE INDEX idx_shelters_geo ON shelters(latitude, longitude)',
    );

    // alert_history
    batch.execute('''
      CREATE TABLE alert_history (
        id TEXT PRIMARY KEY,
        disaster_id TEXT NOT NULL,
        distance_km REAL,
        previous_level TEXT,
        new_level TEXT NOT NULL,
        triggered_at INTEGER,
        notification_status TEXT NOT NULL DEFAULT 'none',
        FOREIGN KEY (disaster_id) REFERENCES disasters(id) ON DELETE CASCADE
      )
    ''');
    batch.execute(
      'CREATE INDEX idx_history_disaster ON alert_history(disaster_id)',
    );
    batch.execute(
      'CREATE INDEX idx_history_time ON alert_history(triggered_at DESC)',
    );

    // sos_events
    batch.execute('''
      CREATE TABLE sos_events (
        id TEXT PRIMARY KEY,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        accuracy REAL,
        status TEXT NOT NULL DEFAULT 'pending',
        channels TEXT,
        contact_ids TEXT,
        message TEXT,
        captured_at INTEGER,
        updated_at INTEGER
      )
    ''');
    batch.execute('CREATE INDEX idx_sos_status ON sos_events(status)');

    // app_settings
    batch.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY,
        value TEXT,
        updated_at INTEGER
      )
    ''');

    // sync_queue (offline outbox)
    batch.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_id TEXT,
        operation TEXT NOT NULL,
        payload TEXT,
        status TEXT NOT NULL DEFAULT 'pending',
        attempts INTEGER NOT NULL DEFAULT 0,
        error TEXT,
        created_at INTEGER,
        synced_at INTEGER
      )
    ''');
    batch.execute(
      'CREATE INDEX idx_sync_status ON sync_queue(status, created_at)',
    );

    _createV2Tables(batch);

    await batch.commit(noResult: true);
  }

  /// Tables introduced in a future schema version.
  ///
  /// Also created for fresh installs at [schemaVersion] so the v2 schema is
  /// fully present from the start.
  static void _createV2Tables(Batch batch) {
    // locations — saved/manual places (city, district, state, PIN, address)
    batch.execute('''
      CREATE TABLE locations (
        id TEXT PRIMARY KEY,
        label TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        mode TEXT NOT NULL DEFAULT 'manual',
        city TEXT,
        district TEXT,
        state TEXT,
        pin_code TEXT,
        address TEXT,
        is_selected INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER,
        updated_at INTEGER
      )
    ''');
    batch.execute(
      'CREATE INDEX idx_locations_selected ON locations(is_selected)',
    );

    // sync_metadata — last-sync watermarks per data source (and global sync)
    batch.execute('''
      CREATE TABLE sync_metadata (
        key TEXT PRIMARY KEY,
        value TEXT,
        updated_at INTEGER
      )
    ''');
  }

  static Future<void> _upgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      // New disaster metadata columns (official-source fields).
      await _addColumnIfMissing(db, 'disasters', 'instructions TEXT');
      await _addColumnIfMissing(db, 'disasters', 'area TEXT');
      await _addColumnIfMissing(db, 'disasters', 'external_url TEXT');
      // locations + sync_metadata tables.
      final batch = db.batch();
      _createV2Tables(batch);
      await batch.commit(noResult: true);
      // Move legacy sync.* watermarks into sync_metadata.
      await _migrateMetaKeys(db);
    }
  }

  static Future<void> _addColumnIfMissing(
    Database db,
    String table,
    String column,
  ) async {
    final name = column.split(' ').first;
    final info = await db.rawQuery('PRAGMA table_info($table)');
    final exists = info.any((row) => row['name'] == name);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column');
    }
  }

  /// Moves legacy `sync.*` watermarks from app_settings into sync_metadata so
  /// existing installs lose no sync state on upgrade.
  static Future<void> _migrateMetaKeys(Database db) async {
    final rows = await db.query(
      'app_settings',
      where: "key LIKE 'sync.%'",
    );
    for (final row in rows) {
      final key = row['key'] as String?;
      final value = row['value'] as String?;
      if (key == null || value == null) continue;
      await db.insert('sync_metadata', {
        'key': key,
        'value': value,
        'updated_at': row['updated_at'],
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await db.delete('app_settings', where: 'key = ?', whereArgs: [key]);
    }
  }

  Future<void> close() async {
    await _db.close();
  }
}
