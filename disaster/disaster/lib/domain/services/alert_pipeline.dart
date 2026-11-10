import 'dart:async';

import 'package:disaster/core/notifications/local_notification_service.dart';
import 'package:disaster/domain/entities/alert_history_entry.dart';
import 'package:disaster/domain/enums/alert_level.dart';
import 'package:disaster/domain/entities/disaster.dart';
import 'package:disaster/domain/repositories/alert_history_repository.dart';
import 'package:disaster/domain/repositories/disaster_repository.dart';
import 'package:disaster/domain/repositories/settings_repository.dart';
import 'package:disaster/domain/services/active_location.dart';
import 'package:disaster/domain/services/location_service.dart';
import 'package:disaster/core/utils/geo_distance.dart';

/// Result of processing a single disaster event through the pipeline.
class PipelineResult {
  const PipelineResult({
    required this.disaster,
    required this.level,
    this.distanceKm,
    this.notified = false,
    this.skippedReason,
    this.historyId,
  });

  final Disaster disaster;
  final AlertLevel level;
  final double? distanceKm;
  final bool notified;
  final String? skippedReason;
  final String? historyId;

  bool get skipped => skippedReason != null;
}

/// Central real-time processing pipeline:
///
/// incoming event -> validate -> save SQLite -> get GPS -> Haversine distance
/// -> determine level -> update state -> notification -> save notification
/// status.
///
/// Used by BOTH the real-time path (WebSocket/REST) and the dev simulator so
/// there is exactly one code path.
class AlertPipeline {
  AlertPipeline({
    required this._disasters,
    required this._history,
    required this._settings,
    required this._location,
    required this._notifications,
    this.activeLocation,
  });

  final DisasterRepository _disasters;
  final AlertHistoryRepository _history;
  final SettingsRepository _settings;
  final LocationService _location;
  final LocalNotificationService _notifications;

  /// Reference point used ahead of (re)probing GPS, so manual-location mode
  /// never triggers a GPS permission prompt, and satellite sources don't spam
  /// the GPS.
  final ActiveLocation? activeLocation;

  final _resultsController = StreamController<PipelineResult>.broadcast();
  Stream<PipelineResult> get results => _resultsController.stream;

  final Set<String> _seenIds = <String>{};

  /// Process a single event through the full pipeline.
  Future<PipelineResult> process(Disaster disaster) async {
    try {
      return await _processInner(disaster);
    } catch (e) {
      // Never let the pipeline crash the app.
      return PipelineResult(
        disaster: disaster,
        level: AlertLevel.safe,
        skippedReason: 'pipeline_error: $e',
      );
    }
  }

  /// Process a batch (e.g. from a REST catch-up or simulator burst).
  Future<List<PipelineResult>> processAll(List<Disaster> events) async {
    final results = <PipelineResult>[];
    for (final e in events) {
      results.add(await process(e));
    }
    return results;
  }

  Future<PipelineResult> _processInner(Disaster disaster) async {
    // 1. Validation.
    if (!disaster.coordinates.isValid) {
      return PipelineResult(
        disaster: disaster,
        level: AlertLevel.safe,
        skippedReason: 'invalid_coordinates',
      );
    }

    // 2. De-duplication (same id seen recently with no update).
    final fingerprint =
        '${disaster.id}|${disaster.payloadHash ?? disaster.updatedAt}';
    if (_seenIds.contains(fingerprint)) {
      return PipelineResult(
        disaster: disaster,
        level: AlertLevel.safe,
        skippedReason: 'duplicate',
      );
    }
    _seenIds.add(fingerprint);
    if (_seenIds.length > 500) {
      _seenIds.remove(_seenIds.first);
    }

    // 3. Settings-driven filter (disaster type preferences).
    final settings = await _settings.load();
    if (!settings.isTypeSelected(disaster.type.code)) {
      return PipelineResult(
        disaster: disaster,
        level: AlertLevel.safe,
        skippedReason: 'type_disabled',
      );
    }

    // 4. Persist (SQLite).
    await _disasters.upsert(disaster);

    // 5. Get the user's reference point. Manual-location mode supplies a
    //    fixed point and never hits the GPS; otherwise fall back to GPS.
    final userLocation =
        activeLocation?.active ??
        await _location.getCurrentLocation() ??
        await _location.getLastKnownLocation();

    // 6. Compute distance (Haversine) and determine level.
    AlertLevel level = AlertLevel.safe;
    double? distanceKm;
    if (userLocation != null) {
      distanceKm = GeoDistance.haversineKm(userLocation, disaster.coordinates);
      level = disaster.levelForDistance(distanceKm);
      if (level.weight < settings.minimumAlertLevel) {
        level =
            AlertLevel.values[settings.minimumAlertLevel.clamp(
              0,
              AlertLevel.values.length - 1,
            )];
      }
    }

    // 7. Record alert history (only when the level changed or it's new).
    String? historyId;
    final previous = await _history.latestForDisaster(disaster.id);
    final changed = previous == null || previous.newLevel != level;
    if (changed) {
      final entry = AlertHistoryEntry(
        id: '',
        disasterId: disaster.id,
        distanceKm: distanceKm,
        previousLevel: previous?.newLevel,
        newLevel: level,
        triggeredAt: DateTime.now(),
        notificationStatus: NotificationStatus.none,
      );
      await _history.insert(entry);
    }

    // 8. Notification (only when active, within radius, prefs allow AND the
    //    incident hasn't already been notified — prevents re-alerting the
    //    same incident on every refresh or app restart).
    var notified = false;
    var notificationStatus = NotificationStatus.none;
    final alreadyNotified =
        previous != null &&
        previous.notificationStatus == NotificationStatus.sent;
    final escalates =
        previous != null && level.weight > previous.newLevel.weight;
    if (level.isActive &&
        settings.notificationsEnabled &&
        (!alreadyNotified || escalates)) {
      try {
        notified = await _notifications.showAlert(
          id: disaster.id.hashCode & 0x7FFFFFFF,
          title: _titleFor(level, disaster),
          body: _bodyFor(level, disaster, distanceKm),
          payload: disaster.id,
        );
        notificationStatus = notified
            ? NotificationStatus.sent
            : NotificationStatus.failed;
      } catch (_) {
        notificationStatus = NotificationStatus.failed;
      }
    } else if (level.isActive && !settings.notificationsEnabled) {
      notificationStatus = NotificationStatus.suppressed;
    }

    // 9. Save notification status back to history.
    if (changed) {
      final latest = await _history.latestForDisaster(disaster.id);
      if (latest != null) {
        historyId = latest.id;
        await _history.updateNotificationStatus(
          latest.id,
          status: notificationStatus.code,
        );
      }
    }

    final result = PipelineResult(
      disaster: disaster,
      level: level,
      distanceKm: distanceKm,
      notified: notified,
      historyId: historyId,
    );
    if (!_resultsController.isClosed) {
      _resultsController.add(result);
    }
    return result;
  }

  String _titleFor(AlertLevel level, Disaster disaster) {
    switch (level) {
      case AlertLevel.critical:
        return 'CRITICAL: ${disaster.title}';
      case AlertLevel.danger:
        return 'DANGER: ${disaster.title}';
      case AlertLevel.warning:
        return 'WARNING: ${disaster.title}';
      case AlertLevel.safe:
        return disaster.title;
    }
  }

  String _bodyFor(AlertLevel level, Disaster disaster, double? distanceKm) {
    final dist = distanceKm == null
        ? ''
        : ' ~${distanceKm.toStringAsFixed(1)} km away.';
    return '${disaster.severity.name.toUpperCase()} ${disaster.type.code}.$dist${disaster.description != null ? ' ${disaster.description}' : ''}';
  }

  void dispose() {
    _resultsController.close();
  }
}
