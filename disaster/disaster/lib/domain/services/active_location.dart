import 'package:disaster/domain/entities/location_record.dart';
import 'package:disaster/domain/value_objects/coordinates.dart';

/// Single source of truth for "where is the user" that works with **two**
/// modes:
///
///  * `gps`    — live GPS coordinate (needs permission).
///  * `manual` — a persisted, geocoded place the user typed in (works with no
///    permission at all).
///
/// Everything that needs a reference point (alert pipeline, map, home screen)
/// reads [active] / [label] from here, so switching modes is automatic.
class ActiveLocation {
  ActiveLocation({this._mode = LocationMode.gps, this._manual});

  LocationMode _mode;
  Coordinates? _gps;
  LocationRecord? _manual;

  LocationMode get mode => _mode;
  bool get isManual => _mode == LocationMode.manual;
  Coordinates? get gps => _gps;
  LocationRecord? get manual => _manual;

  /// Coordinate the alert engine should use right now.
  Coordinates? get active => isManual ? _manual?.coordinates : _gps;

  /// Human-readable label for the current reference point.
  String get label {
    if (isManual && _manual != null) return _manual!.summary;
    return 'My current location';
  }

  void setMode(LocationMode mode) {
    _mode = mode;
  }

  void updateGps(Coordinates? coordinates) {
    _gps = coordinates;
  }

  void selectManual(LocationRecord record) {
    _manual = record;
    _mode = LocationMode.manual;
  }
}
