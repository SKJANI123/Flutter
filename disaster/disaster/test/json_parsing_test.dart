import 'package:flutter_test/flutter_test.dart';

import 'package:disaster/core/errors/exceptions.dart';
import 'package:disaster/data/remote/models/disaster_event.dart';
import 'package:disaster/data/remote/models/shelter_dto.dart';
import 'package:disaster/domain/entities/shelter.dart';
import 'package:disaster/domain/enums/disaster_status.dart';
import 'package:disaster/domain/enums/disaster_type.dart';
import 'package:disaster/domain/enums/severity.dart';

void main() {
  group('DisasterEventParser', () {
    test('parses a plain disaster object', () {
      final raw = {
        'id': 'd1',
        'type': 'earthquake',
        'title': 'Quake',
        'latitude': 35.5,
        'longitude': 139.7,
        'affected_radius_km': 40,
        'severity': 'severe',
        'status': 'active',
        'magnitude': 6.2,
      };
      final d = DisasterEventParser.tryParseSingle(raw);
      expect(d, isNotNull);
      expect(d!.id, 'd1');
      expect(d.type, DisasterType.earthquake);
      expect(d.coordinates.latitude, 35.5);
      expect(d.affectedRadiusKm, 40);
      expect(d.severity, Severity.severe);
      expect(d.status, DisasterStatus.active);
      expect(d.provider, DataProvider.server);
      expect(d.magnitude, 6.2);
    });

    test('parses a WebSocket envelope wrapping the disaster', () {
      final raw = {
        'type': 'disaster',
        'data': {
          'id': 'd2',
          'disaster_type': 'flood',
          'name': 'Flood warning',
          'lat': 10.0,
          'lng': 20.0,
          'radius': 15,
          'severity': 'extreme',
        },
      };
      final d = DisasterEventParser.tryParseSingle(raw);
      expect(d, isNotNull);
      expect(d!.id, 'd2');
      expect(d.type, DisasterType.flood);
      expect(d.title, 'Flood warning');
      expect(d.coordinates.longitude, 20.0);
      expect(d.affectedRadiusKm, 15);
    });

    test('parses a list envelope, skipping malformed entries', () {
      final raw = {
        'events': [
          {
            'id': 'd3',
            'type': 'cyclone',
            'latitude': 1,
            'longitude': 2,
            'severity': 'moderate',
          },
          {'id': 'bad', 'type': 'unknown_thing', 'latitude': 1, 'longitude': 2},
          {'id': 'nocoords', 'type': 'storm'},
          'not-a-map',
        ],
      };
      final list = DisasterEventParser.tryParseList(raw);
      expect(list, hasLength(1));
      expect(list.single.id, 'd3');
      expect(list.single.type, DisasterType.cyclone);
    });

    test('returns null for non-disaster frames (heartbeats)', () {
      expect(DisasterEventParser.tryParseSingle({'type': 'ping'}), isNull);
      expect(DisasterEventParser.tryParseSingle('ping'), isNull);
    });

    test('coerces int-valued coordinates to doubles', () {
      final d = DisasterEventParser.tryParseSingle({
        'id': 'd4',
        'type': 'tsunami',
        'latitude': 1,
        'longitude': 2,
      });
      expect(d!.coordinates.latitude, 1.0);
      expect(d.coordinates.longitude, 2.0);
    });

    test('defaults affected radius to 10 km when missing', () {
      final d = DisasterEventParser.tryParseSingle({
        'id': 'd5',
        'type': 'landslide',
        'latitude': 1.0,
        'longitude': 2.0,
      });
      expect(d!.affectedRadiusKm, 10);
      expect(d.severity, Severity.info);
    });

    test('parseSingle throws ParseException on malformed input', () {
      expect(
        () => DisasterEventParser.parseSingle({'type': 'unknown'}),
        throwsA(isA<ParseException>()),
      );
    });

    test('hashPayload is deterministic SHA-256', () {
      final first = DisasterEventParser.hashPayload({'a': 1});
      final second = DisasterEventParser.hashPayload({'a': 1});
      expect(first, second);
      expect(DisasterEventParser.hashPayload({'a': 2}), isNot(second));
    });
  });

  group('ShelterParser', () {
    test('parses a shelter list', () {
      final raw = {
        'shelters': [
          {
            'id': 's1',
            'name': 'Community Hall',
            'latitude': 33.5,
            'longitude': 130.4,
            'address': '1 Main St',
            'phone': '+81 123456',
            'type': 'relief_camp',
            'capacity': 200,
            'is_open': true,
          },
        ],
      };
      final list = ShelterParser.tryParseList(raw);
      expect(list, hasLength(1));
      final s = list.single;
      expect(s.id, 's1');
      expect(s.type, SafePlaceType.reliefCamp);
      expect(s.capacity, 200);
      expect(s.isOpen, isTrue);
      expect(s.coordinates.longitude, 130.4);
    });

    test('skips entries without id or coordinates', () {
      final raw = {
        'data': [
          {'name': 'missing id', 'latitude': 1, 'longitude': 2},
          {'id': 'no lat', 'longitude': 2},
          {'id': 'ok', 'name': 'Fine', 'latitude': 1.0, 'longitude': 2.0},
        ],
      };
      final list = ShelterParser.tryParseList(raw);
      expect(list, hasLength(1));
      expect(list.single.id, 'ok');
    });

    test('defaults type to shelter and isOpen to true', () {
      final list = ShelterParser.tryParseList({
        'places': [
          {'id': 's2', 'latitude': 0.0, 'longitude': 0.0},
        ],
      });
      expect(list.single.type, SafePlaceType.shelter);
      expect(list.single.isOpen, isTrue);
      expect(list.single.name, 'Safe place');
    });
  });
}
