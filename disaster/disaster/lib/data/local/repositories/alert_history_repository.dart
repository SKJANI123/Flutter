import 'package:disaster/data/local/database/app_database.dart';
import 'package:disaster/data/local/database/mappers.dart';
import 'package:disaster/domain/entities/alert_history_entry.dart';
import 'package:disaster/domain/entities/disaster.dart';
import 'package:disaster/domain/enums/alert_level.dart';
import 'package:disaster/domain/enums/disaster_type.dart';
import 'package:disaster/domain/repositories/alert_history_repository.dart';
import 'package:uuid/uuid.dart';

class LocalAlertHistoryRepository implements AlertHistoryRepository {
  LocalAlertHistoryRepository(this._appDb);

  final AppDatabase _appDb;
  static const _table = 'alert_history';

  Future<Disaster?> _disasterFor(String id) async {
    final rows = await _appDb.db.query(
      'disasters',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DisasterMappers.fromRow(rows.first);
  }

  Future<AlertHistoryEntry> _fromRow(Map<String, dynamic> row) async {
    final disaster = await _disasterFor(row['disaster_id'] as String);
    return AlertHistoryEntry(
      id: row['id'] as String,
      disasterId: row['disaster_id'] as String,
      distanceKm: (row['distance_km'] as num?)?.toDouble(),
      previousLevel: row['previous_level'] == null
          ? null
          : AlertLevel.fromCode(row['previous_level'] as String?),
      newLevel: AlertLevel.fromCode(row['new_level'] as String?),
      triggeredAt: row['triggered_at'] is int
          ? DateTime.fromMillisecondsSinceEpoch(row['triggered_at'] as int)
          : null,
      notificationStatus: NotificationStatus.fromCode(
        row['notification_status'] as String?,
      ),
      disaster: disaster,
    );
  }

  @override
  Future<void> insert(AlertHistoryEntry entry) async {
    final id = entry.id.isEmpty ? const Uuid().v4() : entry.id;
    await _appDb.db.insert(_table, {
      'id': id,
      'disaster_id': entry.disasterId,
      'distance_km': entry.distanceKm,
      'previous_level': entry.previousLevel?.code,
      'new_level': entry.newLevel.code,
      'triggered_at':
          entry.triggeredAt?.millisecondsSinceEpoch ??
          DateTime.now().millisecondsSinceEpoch,
      'notification_status': entry.notificationStatus.code,
    });
  }

  @override
  Future<AlertHistoryEntry?> latestForDisaster(String disasterId) async {
    final rows = await _appDb.db.query(
      _table,
      where: 'disaster_id = ?',
      whereArgs: [disasterId],
      orderBy: 'triggered_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  @override
  Future<List<AlertHistoryEntry>> getAll({int limit = 200}) async {
    final rows = await _appDb.db.query(
      _table,
      orderBy: 'triggered_at DESC',
      limit: limit,
    );
    return _consume(rows);
  }

  @override
  Future<List<AlertHistoryEntry>> search({
    String? query,
    List<DisasterType>? types,
    AlertLevel? minLevel,
  }) async {
    final where = <String>[];
    final args = <Object?>[];

    if (types != null && types.isNotEmpty) {
      where.add('d.type IN (${List.filled(types.length, '?').join(',')})');
      args.addAll(types.map((t) => t.code));
    }
    if (minLevel != null) {
      final levels = AlertLevel.values
          .where((l) => l.weight >= minLevel.weight)
          .toList();
      where.add(
        'ah.new_level IN (${List.filled(levels.length, '?').join(',')})',
      );
      args.addAll(levels.map((l) => l.code));
    }
    if (query != null && query.trim().isNotEmpty) {
      where.add('(d.title LIKE ? OR d.type LIKE ? OR d.source LIKE ?)');
      final like = '%${query.trim()}%';
      args.addAll([like, like, like]);
    }

    final sql =
        '''
      SELECT ah.* FROM alert_history ah
      LEFT JOIN disasters d ON d.id = ah.disaster_id
      ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'}
      ORDER BY ah.triggered_at DESC LIMIT 300
    ''';
    final rows = await _appDb.db.rawQuery(sql, args);
    return _consume(rows);
  }

  Future<List<AlertHistoryEntry>> _consume(
    List<Map<String, dynamic>> rows,
  ) async {
    final entries = <AlertHistoryEntry>[];
    for (final row in rows) {
      entries.add(await _fromRow(row));
    }
    return entries;
  }

  @override
  Future<void> updateNotificationStatus(
    String id, {
    required String status,
  }) async {
    await _appDb.db.update(
      _table,
      {'notification_status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> deleteOlderThan(DateTime before) async {
    await _appDb.db.delete(
      _table,
      where: 'triggered_at < ?',
      whereArgs: [before.millisecondsSinceEpoch],
    );
  }
}
