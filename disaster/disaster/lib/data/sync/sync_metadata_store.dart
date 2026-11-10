import 'package:sqflite/sqflite.dart' hide DatabaseException;

import 'package:disaster/data/local/database/app_database.dart';

/// Tiny key-value metadata store (sync watermarks, per-source watermarks,
/// last-sync timestamps) backed by the `sync_metadata` table.
class SyncMetadataStore {
  SyncMetadataStore(this._appDb);

  static const _table = 'sync_metadata';

  final AppDatabase _appDb;

  Future<void> write(String key, String value) async {
    await _appDb.db.insert(_table, {
      'key': key,
      'value': value,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> read(String key) async {
    final rows = await _appDb.db.query(
      _table,
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }
}
