import 'package:flutter_test/flutter_test.dart';

import 'package:disaster/core/utils/geo_distance.dart';
import 'package:disaster/domain/value_objects/coordinates.dart';

void main() {
  const tokyo = Coordinates(35.6812, 139.7671);
  const osaka = Coordinates(34.6937, 135.5023);

  group('GeoDistance.haversineKm', () {
    test('identical points are 0 km apart', () {
      expect(GeoDistance.haversineKm(tokyo, tokyo), 0);
      expect(GeoDistance.haversineMeters(tokyo, tokyo), 0);
    });

    test('Tokyo -> Osaka is about 400 km', () {
      expect(GeoDistance.haversineKm(tokyo, osaka), closeTo(400, 25));
    });

    test('is symmetric regardless of argument order', () {
      final a = GeoDistance.haversineKm(tokyo, osaka);
      final b = GeoDistance.haversineKm(osaka, tokyo);
      expect(a, closeTo(b, 0.0000001));
    });

    test('one degree of longitude at the equator is ~111 km', () {
      const e1 = Coordinates(0, 0);
      const e2 = Coordinates(0, 1);
      expect(GeoDistance.haversineKm(e1, e2), closeTo(111.19, 0.2));
    });

    test('haversineMeters is 1000x haversineKm', () {
      final km = GeoDistance.haversineKm(tokyo, osaka);
      final m = GeoDistance.haversineMeters(tokyo, osaka);
      expect(m, closeTo(km * 1000, 0.001));
    });
  });

  group('GeoDistance.isWithinRadius', () {
    test('true when distance is at most the radius', () {
      expect(GeoDistance.isWithinRadius(tokyo, osaka, 450), isTrue);
      expect(GeoDistance.isWithinRadius(tokyo, tokyo, 1), isTrue);
    });

    test('false when distance exceeds the radius', () {
      expect(GeoDistance.isWithinRadius(tokyo, osaka, 350), isFalse);
    });
  });
}
