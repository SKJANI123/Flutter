import 'dart:convert';

import 'package:sqflite/sqflite.dart' hide DatabaseException;

import 'package:disaster/data/local/database/app_database.dart';
import 'package:disaster/domain/entities/app_settings.dart';
import 'package:disaster/domain/repositories/settings_repository.dart';

class LocalSettingsRepository implements SettingsRepository {
  LocalSettingsRepository(this._appDb);

  final AppDatabase _appDb;
  static const _table = 'app_settings';
  static const _key = 'app_settings';

  @override
  Future<AppSettings> load() async {
    try {
      final rows = await _appDb.db.query(
        _table,
        where: 'key = ?',
        whereArgs: [_key],
        limit: 1,
      );
      if (rows.isEmpty) return const AppSettings();
      final raw = rows.first['value'] as String?;
      if (raw == null || raw.isEmpty) return const AppSettings();
      return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const AppSettings();
    }
  }

  @override
  Future<void> save(AppSettings settings) async {
    await _appDb.db.insert(_table, {
      'key': _key,
      'value': jsonEncode(settings.toJson()),
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> setOnboardingCompleted(bool value) async {
    final current = await load();
    await save(current.copyWith(onboardingCompleted: value));
  }
}
