import 'package:disaster/data/local/database/app_database.dart';
import 'package:disaster/data/local/database/mappers.dart';
import 'package:disaster/domain/entities/disaster.dart';
import 'package:disaster/domain/enums/disaster_status.dart';
import 'package:disaster/domain/enums/disaster_type.dart';
import 'package:disaster/domain/repositories/disaster_repository.dart';

/// SQLite-backed [DisasterRepository]. Every statement is parameterized.
class LocalDisasterRepository implements DisasterRepository {
  LocalDisasterRepository(this._appDb);

  final AppDatabase _appDb;

  static const _table = 'disasters';

  @override
  Future<Disaster?> findById(String id) async {
    final rows = await _appDb.db.query(
      _table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DisasterMappers.fromRow(rows.first);
  }

  @override
  Future<void> upsert(Disaster disaster) async {
    final row = DisasterMappers.toRow(disaster);
    await _appDb.db.rawInsert(_upsertStatement(row.keys), row.values.toList());
  }

  @override
  Future<void> upsertAll(List<Disaster> disasters) async {
    final batch = _appDb.db.batch();
    for (final d in disasters) {
      final row = DisasterMappers.toRow(d);
      batch.execute(_upsertStatement(row.keys), row.values.toList());
    }
    await batch.commit(noResult: true);
  }

  /// True upsert (`ON CONFLICT DO UPDATE`) that never deletes the existing row,
  /// so `alert_history` rows referencing this disaster survive re-pushes.
  static String _upsertStatement(Iterable<String> keys) {
    final cols = keys.toList();
    final placeholders = List.filled(cols.length, '?').join(', ');
    final assignments = cols
        .where((c) => c != 'id')
        .map((c) => '$c = excluded.$c')
        .join(', ');
    return 'INSERT INTO $_table (${cols.join(', ')}) VALUES ($placeholders) '
        'ON CONFLICT(id) DO UPDATE SET $assignments';
  }

  @override
  Future<List<Disaster>> findAll({
    List<DisasterType>? types,
    bool onlyActive = true,
    int? limit,
    int offset = 0,
  }) async {
    final where = <String>[];
    final args = <Object?>[];
    if (onlyActive) {
      where.add('status = ?');
      args.add(DisasterStatus.active.code);
    }
    if (types != null && types.isNotEmpty) {
      final q = List.filled(types.length, '?').join(',');
      where.add('type IN ($q)');
      args.addAll(types.map((t) => t.code));
    }
    final rows = await _appDb.db.query(
      _table,
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'updated_at DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(DisasterMappers.fromRow).toList();
  }

  @override
  Future<List<Disaster>> findAllActive() =>
      findAll(onlyActive: true, limit: 500);

  @override
  Future<List<Disaster>> findByProvider(
    String provider, {
    bool onlyActive = true,
  }) async {
    final rows = await _appDb.db.query(
      _table,
      where: provider == 'all' ? null : 'provider = ?',
      whereArgs: provider == 'all' ? null : <Object?>[provider],
      orderBy: 'updated_at DESC',
      limit: 500,
    );
    return rows.map(DisasterMappers.fromRow).toList();
  }

  @override
  Future<int> count() async {
    final result = await _appDb.db.rawQuery(
      'SELECT COUNT(*) AS c FROM $_table',
    );
    return ((result.first['c'] as num?) ?? 0).toInt();
  }

  @override
  Future<void> deleteById(String id) async {
    await _appDb.db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> deleteOlderThan(DateTime before) async {
    await _appDb.db.delete(
      _table,
      where: 'expires_at < ? AND (status = ? OR status = ?)',
      whereArgs: [
        before.millisecondsSinceEpoch,
        DisasterStatus.resolved.code,
        DisasterStatus.expired.code,
      ],
    );
  }

  @override
  Future<void> clearSimulatorData() async {
    await _appDb.db.delete(
      _table,
      where: 'provider = ?',
      whereArgs: [DataProvider.simulator.value],
    );
  }

  @override
  Future<void> close() async {}
}
