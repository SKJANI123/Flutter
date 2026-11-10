import 'dart:async';
import 'dart:math';

import 'package:disaster/core/config/app_config.dart';
import 'package:disaster/domain/entities/disaster.dart';
import 'package:disaster/domain/enums/disaster_status.dart';
import 'package:disaster/domain/enums/disaster_type.dart';
import 'package:disaster/domain/enums/severity.dart';
import 'package:disaster/domain/repositories/disaster_repository.dart';
import 'package:disaster/domain/services/alert_pipeline.dart';
import 'package:disaster/domain/value_objects/coordinates.dart';
import 'package:uuid/uuid.dart';

enum SimulatorEventKind { single, burst, critical }

/// DEV/TEST ONLY simulator.
///
/// Generates realistic disaster events around a configurable centre and pushes
/// them through the same [AlertPipeline] as production events, so distance
/// rating, history and notifications behave identically.
///
/// Isolation rules:
/// - every generated event carries `provider = simulator`, stored in SQLite
/// - the simulator is disabled in production builds by default
/// - simulator data can be purged with [clearSimulatorData]
class DisasterSimulator {
  DisasterSimulator({
    required this._pipeline,
    required this._disasters,
    required double centerLat,
    required double centerLng,
    this._defaultRadiusKm = 60,
  }) : _center = Coordinates(centerLat, centerLng);

  final AlertPipeline _pipeline;
  final DisasterRepository _disasters;
  final Coordinates _center;
  final double _defaultRadiusKm;
  final _random = Random();

  Timer? _autoTimer;
  bool _autoRunning = false;

  Coordinates get center => _center;

  /// Whether the simulator is allowed to run in this build.
  bool get isDisabledInBuild => !AppConfig.isDev;

  Future<Disaster> simulateOne({
    DisasterType type = DisasterType.earthquake,
    Severity severity = Severity.moderate,
    double? radiusKm,
    double? distanceOffsetKm,
    String? id,
  }) async {
    final disaster = _buildEvent(
      type: type,
      severity: severity,
      radiusKm: radiusKm,
      distanceOffsetKm: distanceOffsetKm,
      id: id,
    );
    await _pipeline.process(disaster);
    return disaster;
  }

  Future<List<Disaster>> simulateBurst({
    DisasterType type = DisasterType.flood,
    int count = 5,
    Severity severity = Severity.moderate,
  }) async {
    final events = List.generate(
      count,
      (_) => _buildEvent(type: type, severity: severity),
      growable: true,
    );
    // A slight stagger so the real-time feel is preserved.
    for (var i = 0; i < events.length; i++) {
      if (i > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 120));
      }
      await _pipeline.process(events[i]);
    }
    return events;
  }

  /// Generates a "worst case" critical event close to the centre.
  Future<Disaster> simulateCritical({DisasterType? type}) async {
    final disaster = _buildEvent(
      type: type ?? DisasterType.cyclone,
      severity: Severity.extreme,
      distanceOffsetKm: 1.5,
    );
    await _pipeline.process(disaster);
    return disaster;
  }

  Future<void> simulateByKind(SimulatorEventKind kind) async {
    switch (kind) {
      case SimulatorEventKind.single:
        await simulateOne();
      case SimulatorEventKind.burst:
        await simulateBurst();
      case SimulatorEventKind.critical:
        await simulateCritical();
    }
  }

  /// Starts automatic timed generation (dev only).
  void startAuto({Duration interval = const Duration(seconds: 45)}) {
    if (isDisabledInBuild) return;
    if (_autoRunning) return;
    _autoRunning = true;
    _autoTimer = Timer.periodic(interval, (_) async {
      final roll = _random.nextDouble();
      if (roll < 0.15) {
        await simulateCritical();
      } else if (roll < 0.45) {
        await simulateBurst(count: 3);
      } else {
        final index = _random.nextInt(DisasterType.values.length);
        await simulateOne(type: DisasterType.values[index]);
      }
    });
  }

  void stopAuto() {
    _autoTimer?.cancel();
    _autoTimer = null;
    _autoRunning = false;
  }

  Future<void> clearSimulatorData() => _disasters.clearSimulatorData();

  Disaster _buildEvent({
    required DisasterType type,
    required Severity severity,
    double? radiusKm,
    double? distanceOffsetKm,
    String? id,
  }) {
    final radius =
        radiusKm ?? (_defaultRadiusKm * (0.4 + _random.nextDouble() * 1.2));
    final offsetKm =
        distanceOffsetKm ?? (radius * (0.05 + _random.nextDouble() * 0.9));
    final angle = _random.nextDouble() * 2 * pi;

    final lat = _center.latitude + (offsetKm / 111.0) * cos(angle);
    final lng =
        _center.longitude +
        (offsetKm / (111.0 * cos(_center.latitude * pi / 180))).clamp(
              -180,
              180,
            ) *
            sin(angle);

    final now = DateTime.now();
    return Disaster(
      id: id ?? 'sim-${const Uuid().v4().substring(0, 8)}',
      type: type,
      title: '${_simTitle(type)} (sim)',
      description:
          'Synthetic event generated by the dev disaster simulator. '
          'It is clearly tagged as simulator data and never mixed with '
          'production alerts.',
      coordinates: Coordinates(lat, lng),
      affectedRadiusKm: radius,
      severity: severity,
      magnitude: type == DisasterType.earthquake
          ? 3 + _random.nextDouble() * 5
          : null,
      status: DisasterStatus.active,
      occurredAt: now,
      expiresAt: now.add(Duration(hours: 2 + _random.nextInt(10))),
      createdAt: now,
      updatedAt: now,
      source: 'simulator',
      provider: DataProvider.simulator,
    );
  }

  String _simTitle(DisasterType type) {
    const titles = {
      'earthquake': 'Simulated Earthquake',
      'flood': 'Simulated Flooding',
      'cyclone': 'Simulated Cyclone',
      'tsunami': 'Simulated Tsunami',
      'landslide': 'Simulated Landslide',
      'wildfire': 'Simulated Wildfire',
      'heavy_rain': 'Simulated Heavy Rain',
      'lightning': 'Simulated Lightning',
      'storm': 'Simulated Storm',
      'extreme_heat': 'Simulated Heatwave',
    };
    return titles[type.code] ?? 'Simulated Event';
  }

  void dispose() {
    stopAuto();
  }
}
