import 'dart:convert';

import 'package:disaster/data/local/database/app_database.dart';

/// A queued operation to be pushed to the server once connectivity returns
/// (offline outbox).
class SyncQueueItem {
  const SyncQueueItem({
    this.id,
    required this.entityType,
    this.entityId,
    required this.operation,
    this.payload,
    this.status = 'pending',
    this.attempts = 0,
    this.error,
    this.createdAt,
    this.syncedAt,
  });

  final int? id;
  final String entityType;
  final String? entityId;
  final String operation;
  final String? payload;
  final String status;
  final int attempts;
  final String? error;
  final DateTime? createdAt;
  final DateTime? syncedAt;

  Map<String, Object?> toJson() => {
    'entity_type': entityType,
    'entity_id': entityId,
    'operation': operation,
    'payload': payload,
    'status': status,
    'attempts': attempts,
    'error': error,
    'created_at': createdAt?.millisecondsSinceEpoch,
    'synced_at': syncedAt?.millisecondsSinceEpoch,
  };
}

/// SQLite outbox used by the sync service.
class SyncQueueRepository {
  SyncQueueRepository(this._appDb);

  final AppDatabase _appDb;
  static const _table = 'sync_queue';

  Future<int> enqueue({
    required String entityType,
    String? entityId,
    required String operation,
    Map<String, dynamic>? payload,
    String status = 'pending',
  }) async {
    return _appDb.db.insert(_table, {
      'entity_type': entityType,
      'entity_id': entityId,
      'operation': operation,
      'payload': payload == null ? null : jsonEncode(payload),
      'status': status,
      'attempts': 0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<SyncQueueItem>> pending({int limit = 50}) async {
    final rows = await _appDb.db.query(
      _table,
      where: 'status = ?',
      whereArgs: ['pending'],
      orderBy: 'created_at ASC',
      limit: limit,
    );
    return rows.map(_fromRow).toList();
  }

  Future<void> markDone(int id) async {
    await _appDb.db.update(
      _table,
      {'status': 'synced', 'synced_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markFailed(int id, String error) async {
    await _appDb.db.rawUpdate(
      "UPDATE $_table SET status = 'failed', error = ?, attempts = attempts + 1 WHERE id = ?",
      [error, id],
    );
  }

  Future<void> retry(int id) async {
    await _appDb.db.update(
      _table,
      {'status': 'pending', 'error': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> countPending() async {
    final r = await _appDb.db.rawQuery(
      'SELECT COUNT(*) AS c FROM $_table WHERE status = ?',
      ['pending'],
    );
    return ((r.first['c'] as num?) ?? 0).toInt();
  }

  Future<void> purgeSynced({DateTime? before}) async {
    final cut =
        before?.millisecondsSinceEpoch ??
        DateTime.now()
            .subtract(const Duration(days: 30))
            .millisecondsSinceEpoch;
    final where = before == null
        ? 'status = ? AND synced_at < ?'
        : 'status = ?';
    await _appDb.db.delete(
      _table,
      where: where,
      whereArgs: before == null ? ['synced', cut] : ['synced'],
    );
  }

  SyncQueueItem _fromRow(Map<String, dynamic> row) => SyncQueueItem(
    id: row['id'] as int,
    entityType: row['entity_type'] as String,
    entityId: row['entity_id'] as String?,
    operation: row['operation'] as String,
    payload: row['payload'] as String?,
    status: row['status'] as String,
    attempts: ((row['attempts'] as num?) ?? 0).toInt(),
    error: row['error'] as String?,
    createdAt: row['created_at'] is int
        ? DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int)
        : null,
    syncedAt: row['synced_at'] is int
        ? DateTime.fromMillisecondsSinceEpoch(row['synced_at'] as int)
        : null,
  );
}
