import 'package:sqflite/sqflite.dart' hide DatabaseException;

import 'package:disaster/data/local/database/app_database.dart';
import 'package:disaster/domain/entities/shelter.dart';
import 'package:disaster/domain/repositories/shelter_repository.dart';
import 'package:disaster/domain/value_objects/coordinates.dart';

class LocalShelterRepository implements ShelterRepository {
  LocalShelterRepository(this._appDb);

  final AppDatabase _appDb;
  static const _table = 'shelters';

  Shelter _fromRow(Map<String, dynamic> row) => Shelter(
    id: row['id'] as String,
    name: row['name'] as String,
    address: row['address'] as String?,
    coordinates: Coordinates(
      (row['latitude'] as num).toDouble(),
      (row['longitude'] as num).toDouble(),
    ),
    phone: row['phone'] as String?,
    type: SafePlaceType.fromCode(row['type'] as String?),
    capacity: (row['capacity'] as num?)?.toInt(),
    isOpen: ((row['is_open'] as num?) ?? 1) == 1,
    source: row['source'] as String? ?? 'server',
  );

  Map<String, dynamic> _toRow(Shelter s) => {
    'id': s.id,
    'name': s.name,
    'address': s.address,
    'latitude': s.coordinates.latitude,
    'longitude': s.coordinates.longitude,
    'phone': s.phone,
    'type': s.type.code,
    'capacity': s.capacity,
    'is_open': s.isOpen ? 1 : 0,
    'source': s.source,
  };

  @override
  Future<List<Shelter>> getAll() async {
    final rows = await _appDb.db.query(
      _table,
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(_fromRow).toList();
  }

  @override
  Future<Shelter?> getById(String id) async {
    final rows = await _appDb.db.query(
      _table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  @override
  Future<void> upsert(Shelter shelter) async {
    await _appDb.db.insert(
      _table,
      _toRow(shelter),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> upsertAll(List<Shelter> shelters) async {
    final batch = _appDb.db.batch();
    for (final s in shelters) {
      batch.insert(
        _table,
        _toRow(s),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<void> deleteById(String id) async {
    await _appDb.db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }
}
