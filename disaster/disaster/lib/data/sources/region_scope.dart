import 'dart:math' as math;

import 'package:disaster/core/utils/geo_distance.dart';
import 'package:disaster/domain/value_objects/coordinates.dart';

/// Axis-aligned bounding box around a reference point (km -> degrees).
class GeoBox {
  const GeoBox({
    required this.minLat,
    required this.maxLat,
    required this.minLon,
    required this.maxLon,
  });

  final double minLat;
  final double maxLat;
  final double minLon;
  final double maxLon;
}

/// Turns the user's active location into a rough *region scope* so real
/// incident feeds only deliver disasters relevant to where the user is.
///
///  * [boxFor] produces server-side bounding-box params (USGS supports them).
///  * [insideRadius] is a circular client-side check for feeds without box
///    support (GDACS RSS).
///
/// A `null` reference point or `radiusKm <= 0` means **unbounded / global**,
/// so behaviour is unchanged when the user has no location.
class RegionScope {
  RegionScope._();

  static const double _kmPerDegreeLat = 111.32;

  /// Axis-aligned square of half-width [radiusKm] around [referencePoint].
  /// Returns null (global) when the reference point is unknown or the radius
  /// is not positive.
  static GeoBox? boxFor(Coordinates? referencePoint, double radiusKm) {
    if (referencePoint == null || radiusKm <= 0) return null;
    final dLat = radiusKm / _kmPerDegreeLat;
    final cosLat = math.cos(referencePoint.latitude * math.pi / 180);
    final dLon = cosLat.abs() < 0.01
        ? dLat
        : radiusKm / (_kmPerDegreeLat * cosLat.abs());
    final minLat = _clampLat(referencePoint.latitude - dLat);
    final maxLat = _clampLat(referencePoint.latitude + dLat);
    return GeoBox(
      minLat: minLat,
      maxLat: maxLat,
      minLon: (referencePoint.longitude - dLon).clamp(-180.0, 180.0),
      maxLon: (referencePoint.longitude + dLon).clamp(-180.0, 180.0),
    );
  }

  /// True when [point] lies within [radiusKm] of [referencePoint] (haversine).
  static bool insideRadius(
    Coordinates referencePoint,
    Coordinates point,
    double radiusKm,
  ) => radiusKm > 0 && GeoDistance.haversineKm(referencePoint, point) <= radiusKm;

  static double _clampLat(double lat) => lat.clamp(-90.0, 90.0);
}