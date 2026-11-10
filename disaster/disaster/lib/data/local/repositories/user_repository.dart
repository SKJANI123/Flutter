import 'package:sqflite/sqflite.dart' hide DatabaseException;

import 'package:disaster/data/local/database/app_database.dart';
import 'package:disaster/domain/entities/user_profile.dart';
import 'package:disaster/domain/repositories/user_repository.dart';

class LocalUserRepository implements UserRepository {
  LocalUserRepository(this._appDb);

  final AppDatabase _appDb;
  static const _table = 'users';

  UserProfile _fromRow(Map<String, dynamic> row) => UserProfile(
    id: row['id'] as String,
    name: row['name'] as String?,
    deviceId: row['device_id'] as String?,
    isRegistered: ((row['is_registered'] as num?) ?? 0) == 1,
    createdAt: row['created_at'] is int
        ? DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int)
        : null,
    updatedAt: row['updated_at'] is int
        ? DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int)
        : null,
  );

  Map<String, dynamic> _toRow(UserProfile u) => {
    'id': u.id,
    'name': u.name,
    'device_id': u.deviceId,
    'is_registered': u.isRegistered ? 1 : 0,
    'created_at':
        u.createdAt?.millisecondsSinceEpoch ??
        DateTime.now().millisecondsSinceEpoch,
    'updated_at':
        u.updatedAt?.millisecondsSinceEpoch ??
        DateTime.now().millisecondsSinceEpoch,
  };

  @override
  Future<UserProfile?> getCurrent() async {
    final rows = await _appDb.db.query(
      _table,
      orderBy: 'created_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  @override
  Future<void> upsert(UserProfile user) async {
    await _appDb.db.insert(
      _table,
      _toRow(user),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> delete(String id) async {
    await _appDb.db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }
}
