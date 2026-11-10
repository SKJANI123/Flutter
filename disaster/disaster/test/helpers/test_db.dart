import 'dart:async';

import 'package:disaster/core/network/connectivity_service.dart';
import 'package:disaster/data/local/database/app_database.dart';
import 'package:disaster/domain/entities/disaster.dart';
import 'package:disaster/domain/enums/disaster_status.dart';
import 'package:disaster/domain/enums/disaster_type.dart';
import 'package:disaster/domain/enums/severity.dart';
import 'package:disaster/domain/value_objects/coordinates.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

int _seq = 0;

String nextId(String prefix) =>
    '${prefix}_${_seq++}_${DateTime.now().microsecondsSinceEpoch % 100000}';

/// Opens a brand new in-memory SQLite database through sqflite_common_ffi.
Future<AppDatabase> openTestDatabase() async {
  sqfliteFfiInit();
  return AppDatabase.open(
    factory: databaseFactoryFfi,
    path: inMemoryDatabasePath,
  );
}

/// Builds a fully-populated [Disaster] for tests.
Disaster makeDisaster({
  String? id,
  DisasterType type = DisasterType.earthquake,
  double lat = 0.0,
  double lng = 0.0,
  double radiusKm = 10.0,
  Severity severity = Severity.moderate,
  DisasterStatus status = DisasterStatus.active,
  DataProvider provider = DataProvider.server,
  String? title,
}) {
  return Disaster(
    id: id ?? nextId('d'),
    type: type,
    title: title ?? type.label,
    coordinates: Coordinates(lat, lng),
    affectedRadiusKm: radiusKm,
    severity: severity,
    status: status,
    occurredAt: DateTime.now().subtract(const Duration(minutes: 5)),
    expiresAt: DateTime.now().add(const Duration(hours: 12)),
    createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
    updatedAt: DateTime.now(),
    provider: provider,
  );
}

/// Deterministic, plugin-free [ConnectivityService] for tests.
class FakeConnectivityService implements ConnectivityService {
  FakeConnectivityService({this.online = true});

  bool online;
  final _controller = StreamController<bool>.broadcast();

  @override
  bool get isOnline => online;

  @override
  Stream<bool> get onChanged => _controller.stream;

  @override
  void forceOnline(bool value) {
    if (value != online) {
      online = value;
      _controller.add(value);
    }
  }

  @override
  void dispose() {
    _controller.close();
  }
}

/// A [ConnectivityService] that reports a fixed online state.
ConnectivityService makeConnectivityService({bool online = true}) =>
    FakeConnectivityService(online: online);
