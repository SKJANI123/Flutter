import 'package:flutter_test/flutter_test.dart';

import 'package:disaster/domain/entities/disaster.dart';
import 'package:disaster/domain/enums/alert_level.dart';
import 'package:disaster/domain/enums/disaster_status.dart';
import 'package:disaster/domain/enums/disaster_type.dart';
import 'package:disaster/domain/enums/severity.dart';
import 'package:disaster/domain/value_objects/coordinates.dart';

Disaster _disaster({
  double radiusKm = 100,
  Severity severity = Severity.moderate,
}) {
  return Disaster(
    id: 'level-$radiusKm-$severity',
    type: DisasterType.earthquake,
    title: 'Level test',
    coordinates: const Coordinates(0, 0),
    affectedRadiusKm: radiusKm,
    severity: severity,
    status: DisasterStatus.active,
  );
}

void main() {
  group('Disaster.levelForDistance', () {
    test('within 25% of radius is critical', () {
      final d = _disaster(radiusKm: 100);
      expect(d.levelForDistance(0), AlertLevel.critical);
      expect(d.levelForDistance(25), AlertLevel.critical);
    });

    test('25-50% of radius is danger', () {
      final d = _disaster(radiusKm: 100);
      expect(d.levelForDistance(26), AlertLevel.danger);
      expect(d.levelForDistance(50), AlertLevel.danger);
    });

    test('50-100% of radius is warning', () {
      final d = _disaster(radiusKm: 100);
      expect(d.levelForDistance(51), AlertLevel.warning);
      expect(d.levelForDistance(100), AlertLevel.warning);
    });

    test('beyond the radius is safe for moderate events', () {
      final d = _disaster(radiusKm: 100);
      expect(d.levelForDistance(101), AlertLevel.safe);
      expect(d.levelForDistance(200), AlertLevel.safe);
    });

    test('severe severity escalates a warning-level distance to danger', () {
      final severe = _disaster(radiusKm: 100, severity: Severity.severe);
      expect(severe.levelForDistance(80), AlertLevel.danger);
    });

    test('extreme severity keeps far-away events at danger', () {
      final extreme = _disaster(radiusKm: 100, severity: Severity.extreme);
      expect(extreme.levelForDistance(150), AlertLevel.danger);
    });

    test('a zero-radius disaster still can be dangerous at distance 0', () {
      final d = _disaster(radiusKm: 0);
      expect(d.levelForDistance(0), AlertLevel.critical);
    });
  });

  group('AlertLevel', () {
    test('label getter maps to display text', () {
      expect(AlertLevel.safe.label, 'Safe');
      expect(AlertLevel.warning.label, 'Warning');
      expect(AlertLevel.danger.label, 'Danger');
      expect(AlertLevel.critical.label, 'Critical');
    });

    test('fromCode falls back to safe for unknown codes', () {
      expect(AlertLevel.fromCode('nope'), AlertLevel.safe);
      expect(AlertLevel.fromCode(null), AlertLevel.safe);
    });

    test('fromCode round-trips known codes', () {
      expect(AlertLevel.fromCode('critical'), AlertLevel.critical);
    });

    test('atLeast compares severities by weight', () {
      expect(AlertLevel.danger.atLeast(AlertLevel.warning), isTrue);
      expect(AlertLevel.danger.atLeast(AlertLevel.critical), isFalse);
      expect(AlertLevel.warning.atLeast(AlertLevel.danger), isFalse);
    });

    test('isActive is true for everything above safe', () {
      expect(AlertLevel.safe.isActive, isFalse);
      expect(AlertLevel.warning.isActive, isTrue);
      expect(AlertLevel.critical.isActive, isTrue);
    });
  });
}
