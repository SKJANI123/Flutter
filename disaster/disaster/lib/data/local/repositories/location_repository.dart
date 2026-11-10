import 'package:sqflite/sqflite.dart' hide DatabaseException;

import 'package:disaster/data/local/database/app_database.dart';
import 'package:disaster/domain/entities/location_record.dart';
import 'package:disaster/domain/repositories/location_repository.dart';
import 'package:disaster/domain/value_objects/coordinates.dart';

/// SQLite-backed [LocationRepository] (the `locations` table).
class LocalLocationRepository implements LocationRepository {
  LocalLocationRepository(this._appDb);

  final AppDatabase _appDb;
  static const _table = 'locations';

  @override
  Future<List<LocationRecord>> getAll() async {
    final rows = await _appDb.db.query(
      _table,
      orderBy: 'is_selected DESC, updated_at DESC',
    );
    return rows.map(_fromRow).toList();
  }

  @override
  Future<LocationRecord?> getSelected() async {
    final rows = await _appDb.db.query(
      _table,
      where: 'is_selected = ?',
      whereArgs: [1],
      limit: 1,
    );
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  @override
  Future<void> upsert(LocationRecord l) async {
    final now = DateTime.now();
    await _appDb.db.insert(_table, {
      'id': l.id,
      'label': l.label,
      'latitude': l.coordinates.latitude,
      'longitude': l.coordinates.longitude,
      'mode': l.mode.code,
      'city': l.city,
      'district': l.district,
      'state': l.state,
      'pin_code': l.pinCode,
      'address': l.address,
      'is_selected': l.isSelected ? 1 : 0,
      'created_at': (l.createdAt ?? now).millisecondsSinceEpoch,
      'updated_at': now.millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> setSelected({
    required String locationId,
    required String mode,
  }) async {
    await _appDb.db.update(
      _table,
      {'is_selected': 0},
      where: 'is_selected = ?',
      whereArgs: [1],
    );
    await _appDb.db.update(
      _table,
      {'is_selected': 1, 'mode': mode},
      where: 'id = ?',
      whereArgs: [locationId],
    );
  }

  @override
  Future<void> clearSelected() async {
    await _appDb.db.update(
      _table,
      {'is_selected': 0},
      where: 'is_selected = ?',
      whereArgs: [1],
    );
  }

  @override
  Future<void> delete(String id) async {
    await _appDb.db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  LocationRecord _fromRow(Map<String, dynamic> row) => LocationRecord(
    id: row['id'] as String,
    label: row['label'] as String?,
    coordinates: Coordinates(
      (row['latitude'] as num).toDouble(),
      (row['longitude'] as num).toDouble(),
    ),
    mode: LocationMode.fromCode(row['mode'] as String?),
    city: row['city'] as String?,
    district: row['district'] as String?,
    state: row['state'] as String?,
    pinCode: row['pin_code'] as String?,
    address: row['address'] as String?,
    isSelected: (row['is_selected'] as num? ?? 0) == 1,
    createdAt: _fromEpoch(row['created_at']),
    updatedAt: _fromEpoch(row['updated_at']),
  );

  static DateTime? _fromEpoch(Object? v) =>
      v is int ? DateTime.fromMillisecondsSinceEpoch(v) : null;
}