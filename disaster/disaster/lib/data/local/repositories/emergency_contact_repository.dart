import 'package:disaster/data/local/database/app_database.dart';
import 'package:disaster/domain/entities/emergency_contact.dart';
import 'package:disaster/domain/repositories/emergency_contact_repository.dart';

class LocalEmergencyContactRepository implements EmergencyContactRepository {
  LocalEmergencyContactRepository(this._appDb);

  final AppDatabase _appDb;
  static const _table = 'emergency_contacts';

  EmergencyContact _fromRow(Map<String, dynamic> row) => EmergencyContact(
    id: row['id'] as String,
    name: row['name'] as String,
    phone: row['phone'] as String,
    relationship: row['relationship'] as String?,
    isPrimary: ((row['is_primary'] as num?) ?? 0) == 1,
    isVerified: ((row['is_verified'] as num?) ?? 0) == 1,
    createdAt: row['created_at'] is int
        ? DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int)
        : null,
  );

  Map<String, dynamic> _toRow(EmergencyContact c) => {
    'id': c.id,
    'name': c.name,
    'phone': c.phone,
    'relationship': c.relationship,
    'is_primary': c.isPrimary ? 1 : 0,
    'is_verified': c.isVerified ? 1 : 0,
    'created_at':
        c.createdAt?.millisecondsSinceEpoch ??
        DateTime.now().millisecondsSinceEpoch,
  };

  @override
  Future<List<EmergencyContact>> getAll() async {
    final rows = await _appDb.db.query(
      _table,
      orderBy: 'is_primary DESC, created_at DESC',
    );
    return rows.map(_fromRow).toList();
  }

  @override
  Future<EmergencyContact?> getById(String id) async {
    final rows = await _appDb.db.query(
      _table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  @override
  Future<List<EmergencyContact>> getPrimaryContacts() async {
    final rows = await _appDb.db.query(
      _table,
      where: 'is_primary = ?',
      whereArgs: [1],
      orderBy: 'created_at DESC',
    );
    return rows.map(_fromRow).toList();
  }

  @override
  Future<void> insert(EmergencyContact contact) async {
    await _appDb.db.insert(_table, _toRow(contact));
  }

  @override
  Future<void> update(EmergencyContact contact) async {
    await _appDb.db.update(
      _table,
      _toRow(contact),
      where: 'id = ?',
      whereArgs: [contact.id],
    );
  }

  @override
  Future<void> deleteById(String id) async {
    await _appDb.db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }
}
