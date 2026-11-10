import 'dart:math';

import 'package:disaster/domain/value_objects/coordinates.dart';

/// Pure geospatial helpers. All functions are deterministic and unit-testable.
class GeoDistance {
  GeoDistance._();

  /// Mean Earth radius in kilometers.
  static const double earthRadiusKm = 6371.0088;

  /// m2km / km2m conversion constant.
  static const double mPerKm = 1000.0;

  /// Returns the great-circle distance (Haversine formula) between two
  /// coordinates in kilometers.
  static double haversineKm(Coordinates a, Coordinates b) {
    final lat1 = _toRadians(a.latitude);
    final lat2 = _toRadians(b.latitude);
    final dLat = lat2 - lat1;
    final dLon = _toRadians(b.longitude - a.longitude);

    final h =
        pow(sin(dLat / 2), 2) + cos(lat1) * cos(lat2) * pow(sin(dLon / 2), 2);
    return 2 * earthRadiusKm * asin(min(1.0, sqrt(h)));
  }

  /// Same as [haversineKm] but returns meters.
  static double haversineMeters(Coordinates a, Coordinates b) =>
      haversineKm(a, b) * mPerKm;

  /// True when the distance between [a] and [b] is at most [radiusKm].
  static bool isWithinRadius(Coordinates a, Coordinates b, double radiusKm) =>
      haversineKm(a, b) <= radiusKm;

  static double _toRadians(double deg) => deg * pi / 180.0;
}
