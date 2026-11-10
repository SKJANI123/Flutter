import 'dart:convert';

import 'package:disaster/data/local/database/app_database.dart';
import 'package:disaster/domain/entities/sos_event.dart';
import 'package:disaster/domain/repositories/sos_event_repository.dart';

class LocalSosEventRepository implements SosEventRepository {
  LocalSosEventRepository(this._appDb);

  final AppDatabase _appDb;
  static const _table = 'sos_events';

  SosEvent _fromRow(Map<String, dynamic> row) => SosEvent(
    id: row['id'] as String,
    latitude: (row['latitude'] as num).toDouble(),
    longitude: (row['longitude'] as num).toDouble(),
    accuracy: (row['accuracy'] as num?)?.toDouble(),
    status: SosStatus.fromCode(row['status'] as String?),
    channels: _decodeList(row['channels'])
        .map((e) => SosChannel.fromCode(e))
        .toList(),
    contactIds: _decodeList(row['contact_ids']),
    message: row['message'] as String?,
    capturedAt: row['captured_at'] is int
        ? DateTime.fromMillisecondsSinceEpoch(row['captured_at'] as int)
        : null,
    updatedAt: row['updated_at'] is int
        ? DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int)
        : null,
  );

  List<String> _decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .map((e) => e.toString())
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Map<String, dynamic> _toRow(SosEvent e) => {
    'id': e.id,
    'latitude': e.latitude,
    'longitude': e.longitude,
    'accuracy': e.accuracy,
    'status': e.status.code,
    'channels': jsonEncode(e.channels.map((c) => c.code).toList()),
    'contact_ids': jsonEncode(e.contactIds),
    'message': e.message,
    'captured_at':
        e.capturedAt?.millisecondsSinceEpoch ??
        DateTime.now().millisecondsSinceEpoch,
    'updated_at':
        e.updatedAt?.millisecondsSinceEpoch ??
        DateTime.now().millisecondsSinceEpoch,
  };

  @override
  Future<void> insert(SosEvent event) async {
    await _appDb.db.insert(_table, _toRow(event));
  }

  @override
  Future<List<SosEvent>> getAll({bool newestFirst = true}) async {
    final rows = await _appDb.db.query(
      _table,
      orderBy: 'captured_at ${newestFirst ? 'DESC' : 'ASC'}',
      limit: 100,
    );
    return rows.map(_fromRow).toList();
  }

  @override
  Future<List<SosEvent>> getNeedingSync() async {
    final rows = await _appDb.db.query(
      _table,
      where: 'status IN (?, ?)',
      whereArgs: [SosStatus.pending.code, SosStatus.queued.code],
      orderBy: 'captured_at ASC',
    );
    return rows.map(_fromRow).toList();
  }

  @override
  Future<void> updateStatus(String id, SosStatus status) async {
    await _appDb.db.update(
      _table,
      {
        'status': status.code,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> deleteById(String id) async {
    await _appDb.db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }
}
