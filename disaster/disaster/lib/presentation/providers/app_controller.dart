import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'package:disaster/domain/entities/app_settings.dart';
import 'package:disaster/domain/entities/location_record.dart';
import 'package:disaster/domain/services/disaster_realtime_service.dart';
import 'package:disaster/presentation/navigation/navigator_keys.dart';
import 'package:disaster/presentation/providers/app_dependencies.dart';
import 'package:disaster/presentation/providers/location_controller.dart';
import 'package:disaster/presentation/screens/alert_detail/alert_detail_screen.dart';

/// Application-level controller: settings, theme, onboarding and lifecycle of
/// the realtime + sync + GPS streams.
class AppController extends ChangeNotifier {
  AppController({
    required this.deps,
    required this.locationController,
  }) {
    _init();
  }

  final AppDependencies deps;
  final LocationController locationController;

  AppSettings _settings = const AppSettings();
  AppSettings get settings => _settings;
  ThemeMode get themeMode => _settings.themeMode;

  RealtimeState _realtimeState = RealtimeState.offline;
  RealtimeState get realtimeState => _realtimeState;

  bool get realtimeConnected =>
      _realtimeState == RealtimeState.live ||
      _realtimeState == RealtimeState.polling;

  bool _initializing = true;
  bool get initializing => _initializing;

  StreamSubscription<RealtimeState>? _wsSub;
  StreamSubscription<bool>? _connectivitySub;
  StreamSubscription<Object?>? _positionSub;
  bool _realtimeStarted = false;

  Future<void> _init() async {
    try {
      _settings = await deps.settings.load();
    } catch (_) {
      _settings = const AppSettings();
    }

    // Restore the persisted location mode/manual place into the live holder.
    await _restoreActiveLocation();

    _wsSub = deps.realtime.state.listen((s) {
      _realtimeState = s;
      notifyListeners();
    });

    // Start realtime ingestion + offline-first sync + official feeds.
    startRealtime();
    deps.syncService.start();
    deps.ingestion.start();

    // Notification tap -> open the alert detail screen for that incident.
    deps.localNotifications.setOnTapCallback((payload) {
      if (payload == null || payload.isEmpty) return;
      unawaited(_openDisasterById(payload));
    });

    // Continuous GPS tracking (only when the user wants live GPS).
    unawaited(_startGps());

    _initializing = false;
    notifyListeners();
  }

  Future<void> _restoreActiveLocation() async {
    try {
      final mode = _settings.locationMode;
      deps.activeLocation.setMode(mode);
      if (mode == LocationMode.manual &&
          _settings.selectedLocationId != null) {
        LocationRecord? match;
        final all = await deps.locations.getAll();
        for (final l in all) {
          if (l.id == _settings.selectedLocationId) {
            match = l;
            break;
          }
        }
        if (match != null) {
          deps.activeLocation.selectManual(match);
        } else {
          deps.activeLocation.setMode(LocationMode.gps);
        }
      }
    } catch (_) {
      deps.activeLocation.setMode(LocationMode.gps);
    }
  }

  Future<void> _openDisasterById(String id) async {
    final disaster = await deps.disasters.findById(id);
    if (disaster == null) return;
    final nav = appNavigatorKey.currentState;
    if (nav == null) return;
    nav.push(
      MaterialPageRoute(
        builder: (_) => AlertDetailScreen(
          disaster: disaster,
          userLocation: deps.activeLocation.active,
        ),
      ),
    );
  }

  void startRealtime() {
    if (_realtimeStarted) return;
    _realtimeStarted = true;
    deps.realtime.start();
  }

  Future<void> _startGps() async {
    // Manual-location mode never prompts for / uses GPS.
    if (_settings.locationMode == LocationMode.manual) return;
    try {
      final locationService = deps.location;
      final permission = await locationService.requestPermission();
      final granted =
          permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
      final gps = await locationService.isServiceEnabled();
      locationController.updatePermission(
        granted: granted,
        deniedForever: permission == LocationPermission.deniedForever,
        gps: gps,
      );
      if (granted) {
        _positionSub ??= locationService
            .positionStream(distanceFilterMeters: 100)
            .listen(
              (c) => locationController.updatePosition(c, permission: true),
              onError: (_) => locationController.updatePermission(
                granted: false,
                deniedForever: false,
                gps: false,
              ),
            );
      }
    } catch (_) {}
  }

  Future<void> requestGpsPermission() async {
    if (_settings.locationMode == LocationMode.manual) return;
    try {
      final locationService = deps.location;
      final permission = await locationService.requestPermission();
      final granted =
          permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
      final gps = await locationService.isServiceEnabled();
      locationController.updatePermission(
        granted: granted,
        deniedForever: permission == LocationPermission.deniedForever,
        gps: gps,
      );
      if (granted && _positionSub == null) {
        _positionSub = locationService.positionStream().listen(
          (c) => locationController.updatePosition(c, permission: true),
          onError: (_) {},
        );
      }
      notifyListeners();
    } catch (_) {}
  }

  /// Selects a manual place and switches the app to manual-location mode. The
  /// choice is persisted so it survives restarts.
  Future<void> selectManualLocation(LocationRecord record) async {
    await deps.locations.upsert(record.copyWith(isSelected: true));
    await deps.locations.setSelected(
      locationId: record.id,
      mode: LocationMode.manual.code,
    );
    locationController.switchToManual(record.copyWith(isSelected: true));
    await updateSettings(
      _settings.copyWith(
        locationMode: LocationMode.manual,
        selectedLocationId: record.id,
      ),
    );
    // Weather warnings are scoped to the reference point — re-scope now.
    unawaited(deps.ingestion.refresh());
  }

  /// Switches back to live GPS (persisted).
  Future<void> useGps() async {
    // Clearing the DB selection keeps the previously saved manual place out of
    // "selected" state — GPS mode has no selected record.
    await deps.locations.clearSelected();
    await updateSettings(
      _settings.copyWith(
        locationMode: LocationMode.gps,
        selectedLocationId: null,
      ),
    );
    locationController.switchToGps();
    unawaited(_startGps());
    unawaited(deps.ingestion.refresh());
  }

  Future<void> openAppSettings() => deps.location.openAppSettings();

  Future<void> updateSettings(AppSettings next) async {
    _settings = next;
    await deps.settings.save(next);
    notifyListeners();
  }

  Future<void> setOnboardingDone() async {
    await updateSettings(_settings.copyWith(onboardingCompleted: true));
  }

  Future<void> requestNotificationPermission() async {
    await deps.localNotifications.requestPermission();
  }

  Future<bool> areNotificationsGranted() =>
      deps.localNotifications.areNotificationsEnabled();

  @override
  void dispose() {
    _wsSub?.cancel();
    _connectivitySub?.cancel();
    _positionSub?.cancel();
    super.dispose();
  }
}
