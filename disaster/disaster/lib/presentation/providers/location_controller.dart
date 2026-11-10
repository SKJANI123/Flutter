import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:disaster/domain/entities/location_record.dart';
import 'package:disaster/presentation/providers/app_dependencies.dart';
import 'package:disaster/domain/value_objects/coordinates.dart';

/// Holds the latest known user location and the active mode (GPS vs manual).
///
/// The [AppDependencies.activeLocation] holder is the single source of truth
/// consumed by the alert pipeline; this controller keeps the UI reactive to
/// changes and persists mode changes through [AppController].
class LocationController extends ChangeNotifier {
  LocationController({required AppDependencies deps}) : _deps = deps {
    _subscription = deps.connectivity.onChanged.listen(forceConnectivity);
  }

  final AppDependencies _deps;
  StreamSubscription<bool>? _subscription;
  Coordinates? _lastLocation;
  bool _tracking = false;
  bool _hasPermission = false;
  bool _gpsEnabled = false;
  bool _permissionDeniedForever = false;

  /// Last raw GPS fix (only valid in GPS mode).
  Coordinates? get lastLocation {
    if (_deps.activeLocation.isManual) return null;
    if (_deps.activeLocation.gps != null) return _deps.activeLocation.gps;
    return _lastLocation;
  }

  /// The reference point the app should use right now (GPS or manual).
  Coordinates? get activeLocationCoords => _deps.activeLocation.active;

  bool get isManualMode => _deps.activeLocation.isManual;
  String get locationLabel => _deps.activeLocation.label;
  LocationMode get mode => _deps.activeLocation.mode;

  /// Manual location selected by the user (null in GPS mode).
  LocationRecord? get manualLocation => _deps.activeLocation.manual;

  bool get isTracking => _tracking;
  bool get hasPermission => _hasPermission;
  bool get gpsEnabled => _gpsEnabled;
  bool get permissionDeniedForever => _permissionDeniedForever;

  bool _online = true;
  bool get isOnline => _online;

  void forceConnectivity(bool online) {
    if (_online != online) {
      _online = online;
      notifyListeners();
    }
  }

  void updatePosition(Coordinates? c, {bool permission = false}) {
    _lastLocation = c;
    _deps.activeLocation.updateGps(c);
    _hasPermission = permission;
    _tracking = c != null;
    notifyListeners();
  }

  void updatePermission({
    required bool granted,
    required bool deniedForever,
    required bool gps,
  }) {
    _hasPermission = granted;
    _permissionDeniedForever = deniedForever;
    _gpsEnabled = gps;
    notifyListeners();
  }

  /// Switches the active mode at runtime (mode persistence handled by
  /// [AppController] through settings).
  void switchToGps() {
    _deps.activeLocation.setMode(LocationMode.gps);
    notifyListeners();
  }

  void switchToManual(LocationRecord record) {
    _deps.activeLocation.selectManual(record);
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}