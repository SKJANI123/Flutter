import 'dart:async';

import 'package:geolocator/geolocator.dart';

import 'package:disaster/core/errors/exceptions.dart';
import 'package:disaster/domain/value_objects/coordinates.dart';

/// GPS location service wrapping `geolocator`.
///
/// Every call is guarded: permission denied, disabled GPS and platform quirks
/// never crash the caller — they surface as [LocationException] which callers
/// handle (banners, fallbacks) rather than throwing raw plugin errors.
class LocationService {
  LocationService({PositionStreamProvider? positionProvider})
    : _streamProvider = positionProvider ?? _defaultStreamProvider;

  /// Injected position provider for tests / dev mock.
  final Future<Stream<Position>> Function(LocationSettings) _streamProvider;

  static Future<Stream<Position>> _defaultStreamProvider(
    LocationSettings settings,
  ) async => Geolocator.getPositionStream(locationSettings: settings);

  /// Current permission state (never throws).
  Future<LocationPermission> checkPermission() async {
    try {
      return await Geolocator.checkPermission();
    } catch (_) {
      return LocationPermission.unableToDetermine;
    }
  }

  /// Requests location permission (never throws).
  Future<LocationPermission> requestPermission() async {
    try {
      return await Geolocator.requestPermission();
    } catch (_) {
      return LocationPermission.denied;
    }
  }

  bool _isGranted(LocationPermission permission) =>
      permission == LocationPermission.always ||
      permission == LocationPermission.whileInUse;

  Future<bool> isServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (_) {
      return false;
    }
  }

  /// Ensures permissions and service are available; returns false otherwise.
  Future<bool> ensureReady({bool request = true}) async {
    var permission = await checkPermission();
    if (request && !_isGranted(permission)) {
      permission = await requestPermission();
    }
    if (permission == LocationPermission.deniedForever) return false;
    if (_isGranted(permission) && await isServiceEnabled()) return true;
    return _isGranted(permission);
  }

  Future<Coordinates?> getCurrentLocation() async {
    try {
      if (!await ensureReady(request: true)) return null;
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return Coordinates(position.latitude, position.longitude);
    } on LocationException {
      rethrow;
    } catch (_) {
      return null;
    }
  }

  Future<Coordinates?> getLastKnownLocation() async {
    try {
      final position = await Geolocator.getLastKnownPosition();
      if (position == null) return null;
      return Coordinates(position.latitude, position.longitude);
    } catch (_) {
      return null;
    }
  }

  /// Continuous position stream; emits when user moves more than
  /// [distanceFilterMeters].
  Stream<Coordinates> positionStream({
    int distanceFilterMeters = 50,
    LocationAccuracy accuracy = LocationAccuracy.high,
  }) {
    final controller = StreamController<Coordinates>.broadcast();
    StreamSubscription<Position>? sub;

    Future<void> start() async {
      try {
        final ok = await ensureReady(request: true);
        if (!ok) {
          controller.addError(const LocationException('GPS unavailable'));
          return;
        }
        final stream = await _streamProvider(
          LocationSettings(
            accuracy: accuracy,
            distanceFilter: distanceFilterMeters,
          ),
        );
        sub = stream.listen(
          (p) => controller.add(Coordinates(p.latitude, p.longitude)),
          onError: (Object e) =>
              controller.addError(const LocationException('GPS stream error')),
        );
      } catch (_) {
        controller.addError(const LocationException('GPS unavailable'));
      }
    }

    unawaited(start());
    controller.onCancel = () {
      sub?.cancel();
      controller.close();
    };
    return controller.stream;
  }

  Future<void> openAppSettings() => Geolocator.openAppSettings();
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();
}

/// Type alias for injecting position streams (tests / dev).
typedef PositionStreamProvider = Future<Stream<Position>> Function(
  LocationSettings,
);
