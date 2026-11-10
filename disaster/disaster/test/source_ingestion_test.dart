import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:disaster/data/local/database/app_database.dart';
import 'package:disaster/data/local/repositories/alert_history_repository.dart';
import 'package:disaster/data/local/repositories/disaster_repository.dart';
import 'package:disaster/data/local/repositories/location_repository.dart';
import 'package:disaster/data/local/repositories/settings_repository.dart';
import 'package:disaster/data/remote/api/geocoding_service.dart';
import 'package:disaster/data/sources/disaster_source.dart';
import 'package:disaster/data/sources/gdacs_source.dart';
import 'package:disaster/data/sources/incident_ingestion_service.dart';
import 'package:disaster/data/sources/open_meteo_weather_source.dart';
import 'package:disaster/data/sources/region_scope.dart';
import 'package:disaster/data/sources/source_config.dart';
import 'package:disaster/data/sources/source_health.dart';
import 'package:disaster/data/sources/usgs_earthquake_source.dart';
import 'package:disaster/data/sync/sync_metadata_store.dart';
import 'package:disaster/domain/entities/disaster.dart';
import 'package:disaster/domain/entities/location_record.dart';
import 'package:disaster/domain/enums/alert_level.dart';
import 'package:disaster/domain/enums/disaster_type.dart';
import 'package:disaster/domain/enums/severity.dart';
import 'package:disaster/domain/services/active_location.dart';
import 'package:disaster/domain/services/alert_pipeline.dart';
import 'package:disaster/domain/value_objects/coordinates.dart';

import 'helpers/fakes.dart';
import 'helpers/test_db.dart';

void main() {
  group('UsgsEarthquakeSource.parse', () {
    test('maps a GeoJSON feature to a Disaster entity', () {
      final features = {
        'type': 'FeatureCollection',
        'metadata': const {'count': 1},
        'features': [
          {
            'type': 'Feature',
            'id': 'us7000abc',
            'properties': {
              'mag': 6.1,
              'place': '35 km SE of Kathmandu',
              'time': 1720000000000,
              'url': 'https://earthquake.usgs.gov/event/us7000abc',
              'title': 'M 6.1 - 35 km SE of Kathmandu',
            },
            'geometry': {
              'type': 'Point',
              'coordinates': [85.4, 27.5, 10.0],
            },
          },
          {
            // Malformed: no valid id -> skipped.
            'type': 'Feature',
            'properties': {'mag': 4.0},
            'geometry': {'type': 'Point', 'coordinates': [1.0, 2.0]},
          },
        ],
      };

      final parsed = UsgsEarthquakeSource.parse(features);

      expect(parsed, hasLength(1));
      final d = parsed.single;
      expect(d.id, 'usgs_us7000abc');
      expect(d.type, DisasterType.earthquake);
      expect(d.severity, Severity.severe);
      expect(d.magnitude, 6.1);
      expect(d.coordinates.latitude, 27.5);
      expect(d.coordinates.longitude, 85.4);
      expect(d.provider.value, 'server');
      expect(d.area, '35 km SE of Kathmandu');
      expect(d.externalUrl, contains('us7000abc'));
      expect(d.affectedRadiusKm, greaterThan(100));
    });

    test('returns empty for a non-featurecollection payload', () {
      expect(UsgsEarthquakeSource.parse('nope'), isEmpty);
      expect(UsgsEarthquakeSource.parse(null), isEmpty);
    });
  });

  group('GdacsSource.parse', () {
    test('maps a GeoRSS item and skips unsupported event types', () {
      final rss = '''
<rss version="2.0"
     xmlns:geo="http://www.w3.org/2003/01/geo/wgs84_pos#"
     xmlns:gdacs="http://www.gdacs.org/">
 <channel>
  <item>
    <title>Red flood alert in Thailand</title>
    <description>Severe flooding reported.</description>
    <link>https://www.gdacs.org/report.aspx?eventtype=FL&amp;eventid=1000000</link>
    <guid>FL-2026-000000-THA</guid>
    <geo:lat>15.5</geo:lat>
    <geo:long>101.2</geo:long>
    <gdacs:eventtype>FL</gdacs:eventtype>
    <gdacs:alertlevel>Red</gdacs:alertlevel>
    <gdacs:iscurrent>True</gdacs:iscurrent>
    <gdacs:fromdate>Tue, 22 Sep 2026 06:00:00 GMT</gdacs:fromdate>
    <gdacs:todate>Fri, 25 Sep 2026 06:00:00 GMT</gdacs:todate>
    <gdacs:bbox>100.5 102.0 14.0 17.0</gdacs:bbox>
  </item>
  <item>
    <title>Unknown event</title>
    <guid>XX-2026-000001</guid>
    <geo:lat>1.0</geo:lat>
    <geo:long>2.0</geo:long>
    <gdacs:eventtype>XX</gdacs:eventtype>
  </item>
 </channel>
</rss>
''';

      final parsed = GdacsSource.parse(rss);

      expect(parsed, hasLength(1));
      final d = parsed.single;
      expect(d.id, 'gdacs_FL-2026-000000-THA');
      expect(d.type, DisasterType.flood);
      expect(d.severity, Severity.extreme);
      expect(d.status.code, 'active');
      expect(d.title, contains('Flood Warning'));
      expect(d.title, contains('Thailand'));
      expect(d.source, 'GDACS');
      expect(d.affectedRadiusKm, greaterThan(25));
      expect(d.expiresAt, isNotNull);
      expect(d.externalUrl, contains('gdacs.org'));
    });

    test('malformed xml yields an empty list', () {
      expect(GdacsSource.parse('<not>valid</xml>'), isEmpty);
    });
  });

  group('RegionScope', () {
    const surat = Coordinates(21.17, 72.83);

    test('boxFor converts a radius into a bounding box around the reference', () {
      final box = RegionScope.boxFor(surat, 2000)!;
      expect(box.minLat, closeTo(21.17 - 2000 / 111.32, 0.001));
      expect(box.maxLat, closeTo(21.17 + 2000 / 111.32, 0.001));
      expect(box.minLon, lessThan(72.83));
      expect(box.maxLon, greaterThan(72.83));
      expect(box.minLat, greaterThanOrEqualTo(-90));
      expect(box.maxLat, lessThanOrEqualTo(90));
      // A 2000 km box around Surat must cover all of India but not Europe.
      expect(box.maxLat, greaterThan(35));
      expect(box.minLon, lessThan(68));
      expect(box.maxLon, lessThan(96));
    });

    test('boxFor returns null (global) without a reference or radius', () {
      expect(RegionScope.boxFor(null, 2000), isNull);
      expect(RegionScope.boxFor(surat, 0), isNull);
      expect(RegionScope.boxFor(surat, -5), isNull);
    });

    test('insideRadius keeps near points and drops far ones', () {
      expect(
        RegionScope.insideRadius(surat, const Coordinates(21.2, 72.9), 2000),
        isTrue,
      );
      expect(
        RegionScope.insideRadius(surat, const Coordinates(40.4, -3.7), 2000),
        isFalse,
      );
      expect(
        RegionScope.insideRadius(surat, const Coordinates(21.2, 72.9), 0),
        isFalse,
      );
    });
  });

  group('Regional scoping of sources', () {
    const surat = Coordinates(21.17, 72.83);

    const gdacsConfig = SourceConfigEntry(
      id: 'gdacs',
      name: 'GDACS',
      description: '',
      kind: 'disasters',
      enabled: true,
      params: {'geoRadiusKm': 2000.0},
    );

    const usgsConfig = SourceConfigEntry(
      id: 'usgs',
      name: 'USGS',
      description: '',
      kind: 'earthquakes',
      enabled: true,
      params: {
        'minMagnitude': 5.0,
        'maxAgeHours': 48.0,
        'limit': 100,
        'geoRadiusKm': 2000.0,
      },
    );

    test('GDACS keeps only incidents near the reference point', () async {
      final rss = '''
<rss version="2.0"
     xmlns:geo="http://www.w3.org/2003/01/geo/wgs84_pos#"
     xmlns:gdacs="http://www.gdacs.org/">
 <channel>
  <item>
    <title>Green flood alert in India</title>
    <guid>FL-NEAR</guid>
    <geo:lat>21.2</geo:lat>
    <geo:long>72.9</geo:long>
    <gdacs:eventtype>FL</gdacs:eventtype>
    <gdacs:alertlevel>Green</gdacs:alertlevel>
    <gdacs:iscurrent>True</gdacs:iscurrent>
  </item>
  <item>
    <title>Green flood alert in Spain</title>
    <guid>FL-FAR</guid>
    <geo:lat>40.4</geo:lat>
    <geo:long>-3.7</geo:long>
    <gdacs:eventtype>FL</gdacs:eventtype>
    <gdacs:alertlevel>Green</gdacs:alertlevel>
    <gdacs:iscurrent>True</gdacs:iscurrent>
  </item>
 </channel>
</rss>
''';
      final client = MockClient(
        (_) async => http.Response(rss, 200, headers: {'content-type': 'text/xml'}),
      );

      // With a reference point, the European item is dropped.
      final scoped = await GdacsSource(config: gdacsConfig, client: client)
          .fetch(referencePoint: surat);
      expect(scoped.incidents, hasLength(1));
      expect(scoped.incidents.single.id, 'gdacs_FL-NEAR');

      // Without a reference point, the whole global feed is kept.
      final global = await GdacsSource(config: gdacsConfig, client: client)
          .fetch(referencePoint: null);
      expect(global.incidents, hasLength(2));
    });

    test('USGS adds bounding-box params only when a location is known', () async {
      Uri? captured;
      final client = MockClient((request) async {
        captured = request.url;
        return http.Response(
          '{"type":"FeatureCollection","features":[]}',
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      await UsgsEarthquakeSource(config: usgsConfig, client: client)
          .fetch(referencePoint: surat);
      expect(captured, isNotNull);
      expect(captured!.queryParameters, containsPair('minlatitude', isNotEmpty));
      expect(captured!.queryParameters, containsPair('maxlatitude', isNotEmpty));
      expect(captured!.queryParameters, containsPair('minlongitude', isNotEmpty));
      expect(captured!.queryParameters, containsPair('maxlongitude', isNotEmpty));

      captured = null;
      await UsgsEarthquakeSource(config: usgsConfig, client: client)
          .fetch(referencePoint: null);
      expect(captured, isNotNull);
      expect(captured!.queryParameters.containsKey('minlatitude'), isFalse);
      expect(captured!.queryParameters.containsKey('maxlongitude'), isFalse);
    });
  });

  group('OpenMeteoWeatherSource.parse', () {
    final sample = {
      'latitude': 21.17,
      'longitude': 72.83,
      'daily': {
        'time': ['2026-09-25', '2026-09-26'],
        'weather_code': [2, 75],
        'temperature_2m_max': [40.0, 46.5],
      },
    };

    test('maps severe-snow and extreme-heat days to incidents', () {
      final parsed = OpenMeteoWeatherSource.parse(
        sample,
        referencePoint: const Coordinates(21.17, 72.83),
        heatThresholdC: 45.0,
      );

      expect(parsed, hasLength(2));
      final snow = parsed.firstWhere((d) => d.type == DisasterType.storm);
      expect(snow.severity, Severity.severe);
      expect(snow.expiresAt, isNotNull);
      expect(snow.coordinates.latitude, 21.17);

      final heat = parsed.firstWhere((d) => d.type == DisasterType.extremeHeat);
      expect(heat.severity, Severity.severe);
      expect(heat.description, contains('46.5'));
      expect(heat.source, 'Open-Meteo');
    });

    test('calm days produce no incidents', () {
      final parsed = OpenMeteoWeatherSource.parse(
        {
          'daily': {
            'time': ['2026-09-25'],
            'weather_code': [1],
            'temperature_2m_max': [33.0],
          },
        },
        referencePoint: const Coordinates(0, 0),
      );
      expect(parsed, isEmpty);
    });
  });

  group('GeocodingService.parseResults', () {
    test('extracts named results and skips entries without coordinates', () {
      final raw = {
        'results': [
          {
            'name': 'Surat',
            'latitude': 21.17,
            'longitude': 72.83,
            'country_code': 'IN',
            'country': 'India',
            'admin1': 'Gujarat',
            'postcodes': ['395001'],
          },
          {'name': 'No coords'},
        ],
      };

      final results = GeocodingService.parseResults(raw);

      expect(results, hasLength(1));
      expect(results.single.name, 'Surat');
      expect(results.single.state, 'Gujarat');
      expect(results.single.postcodes, ['395001']);
      expect(results.single.summary, contains('Surat'));
    });
  });

  group('database v2 migration', () {
    late Directory tmpDir;

    setUp(() {
      tmpDir = Directory.systemTemp.createTempSync('disaster_migration');
    });

    tearDown(() {
      try {
        tmpDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('upgrades a v1 database adding tables, columns and meta migration',
        () async {
      sqfliteFfiInit();
      final path = '${tmpDir.path}/v1.db';

      // Create a v1 database with the legacy schema + sync.* watermarks.
      final v1 = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE disasters (
                id TEXT PRIMARY KEY,
                type TEXT NOT NULL,
                title TEXT NOT NULL,
                description TEXT,
                latitude REAL NOT NULL,
                longitude REAL NOT NULL,
                affected_radius_km REAL NOT NULL DEFAULT 0,
                severity TEXT NOT NULL DEFAULT 'info',
                magnitude REAL,
                status TEXT NOT NULL DEFAULT 'active',
                occurred_at INTEGER,
                expires_at INTEGER,
                created_at INTEGER,
                updated_at INTEGER,
                source TEXT,
                provider TEXT NOT NULL DEFAULT 'server',
                payload_hash TEXT
              )
            ''');
            await db.execute('''
              CREATE TABLE app_settings (
                key TEXT PRIMARY KEY,
                value TEXT,
                updated_at INTEGER
              )
            ''');
            await db.insert('app_settings', {
              'key': 'sync.last.disasters',
              'value': '2026-09-20T10:00:00.000Z',
              'updated_at': 0,
            });
          },
        ),
      );
      final v1Columns = await v1.rawQuery('PRAGMA table_info(disasters)');
      expect(v1Columns.map((r) => r['name']), isNot(contains('instructions')));
      await v1.close();

      // Re-open through AppDatabase -> onUpgrade(1 -> 2).
      final upgraded = await AppDatabase.open(
        path: path,
        factory: databaseFactoryFfi,
      );

      final newColumns = await upgraded.db.rawQuery(
        'PRAGMA table_info(disasters)',
      );
      final names = newColumns.map((r) => r['name']).toList();
      expect(names, containsAll(['instructions', 'area', 'external_url']));

      final locations = await upgraded.db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='locations'",
      );
      expect(locations, isNotEmpty);
      final meta = await upgraded.db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='sync_metadata'",
      );
      expect(meta, isNotEmpty);

      // Legacy sync.* key moved out of app_settings into sync_metadata.
      final legacyInSettings =
          await upgraded.db.query(
            'app_settings',
            where: "key LIKE 'sync.%'",
          );
      expect(legacyInSettings, isEmpty);
      final moved = await SyncMetadataStore(upgraded).read(
        'sync.last.disasters',
      );
      expect(moved, '2026-09-20T10:00:00.000Z');

      await upgraded.close();
    });
  });

  group('LocalLocationRepository', () {
    test('round-trips and selection', () async {
      final db = await openTestDatabase();
      final repo = LocalLocationRepository(db);
      final rec = LocationRecord(
        id: 'loc-1',
        label: 'Surat',
        coordinates: const Coordinates(21.17, 72.83),
        mode: LocationMode.manual,
        city: 'Surat',
        district: 'Surat',
        state: 'Gujarat',
        pinCode: '395001',
        isSelected: false,
      );

      await repo.upsert(rec.copyWith(isSelected: true));
      final list = await repo.getAll();
      expect(list, hasLength(1));
      expect(list.single.state, 'Gujarat');
      expect(list.single.isSelected, isTrue);
      expect((await repo.getSelected())!.pinCode, '395001');

      await repo.setSelected(locationId: 'loc-1', mode: 'gps');
      expect((await repo.getSelected())!.mode, LocationMode.gps);

      await repo.clearSelected();
      expect(await repo.getSelected(), isNull);
      expect((await repo.getAll()).single.isSelected, isFalse);

      await repo.delete('loc-1');
      expect(await repo.getAll(), isEmpty);
      await db.close();
    });
  });

  group('IncidentIngestionService', () {
    test('refreshes healthy sources, flags failures and writes watermarks',
        () async {
      final db = await openTestDatabase();
      final disasters = LocalDisasterRepository(db);
      final history = LocalAlertHistoryRepository(db);
      final settings = LocalSettingsRepository(db);
      final pipeline = AlertPipeline(
        disasters: disasters,
        history: history,
        settings: settings,
        location: FakeLocationService(),
        notifications: FakeNotificationService(),
      );
      final connectivity = FakeConnectivityService(online: true);
      final health = SourceHealthRegistry();
      final metadata = SyncMetadataStore(db);
      final activeLocation = ActiveLocation(mode: LocationMode.gps);

      final good = _FakeSource(
        'good',
        incidents: [
          makeDisaster(id: 'ing-1'),
          makeDisaster(id: 'ing-2', type: DisasterType.flood),
        ],
      );
      final bad = _FakeSource('bad', error: const SourceUnavailableException(
        'bad',
        'down',
      ));

      final service = IncidentIngestionService(
        health: health,
        pipeline: pipeline,
        metadata: metadata,
        activeLocation: activeLocation,
        connectivity: connectivity,
        sources: [good, bad],
      );
      service.registerSources();

      final result = await service.refresh();

      expect(result.refreshed, 1);
      expect(result.failed, 1);
      expect(result.incidents, 2);
      expect(result.erroredSources, ['bad']);
      expect(result.allHealthy, isFalse);
      expect(await disasters.findById('ing-1'), isNotNull);
      expect(health.byId('good')!.state, SourceState.ok);
      expect(health.byId('bad')!.state, SourceState.unavailable);
      expect(await metadata.read('source.good.last_sync_at'), isNotNull);
      expect(await metadata.read('source.bad.last_sync_at'), isNull);

      service.dispose();
      await db.close();
      pipeline.dispose();
    });
  });

  group('AlertPipeline notification guard', () {
    test('re-processing the same alert level does not re-notify', () async {
      final db = await openTestDatabase();
      final disasters = LocalDisasterRepository(db);
      final history = LocalAlertHistoryRepository(db);
      final settings = LocalSettingsRepository(db);
      final notifications = FakeNotificationService();
      final activeLocation = ActiveLocation(mode: LocationMode.gps);
      activeLocation.updateGps(const Coordinates(0, 0));

      final pipeline = AlertPipeline(
        disasters: disasters,
        history: history,
        settings: settings,
        location: FakeLocationService(), // no GPS fallback in manual/GPS holder
        notifications: notifications,
        activeLocation: activeLocation,
      );

      final base = makeDisaster(
        id: 'nr-1',
        lat: 0.0,
        lng: 0.0,
        radiusKm: 10,
        severity: Severity.extreme,
      );

      final first = await pipeline.process(base);
      expect(first.level, AlertLevel.critical);
      expect(first.notified, isTrue);
      expect(notifications.shown, hasLength(1));

      // Same level, same alert on the very next refresh -> no duplicate ping.
      final refreshed = await pipeline.process(
        base.copyWith(payloadHash: 'changed'),
      );
      expect(refreshed.level, AlertLevel.critical);
      expect(refreshed.notified, isFalse);
      expect(notifications.shown, hasLength(1));

      pipeline.dispose();
      await db.close();
    });

    test('manual activeLocation is used ahead of GPS position', () async {
      final db = await openTestDatabase();
      final disasters = LocalDisasterRepository(db);
      final history = LocalAlertHistoryRepository(db);
      final settings = LocalSettingsRepository(db);
      final activeLocation = ActiveLocation(mode: LocationMode.manual);
      activeLocation.selectManual(
        const LocationRecord(
          id: 'm-1',
          coordinates: Coordinates(0, 0),
          label: 'Home',
          isSelected: true,
        ),
      );

      final d = makeDisaster(
        id: 'manual-1',
        lat: 0.0,
        lng: 0.0,
        radiusKm: 10,
        severity: Severity.extreme,
      );
      final pipeline = AlertPipeline(
        disasters: disasters,
        history: history,
        settings: settings,
        // GPS is "far away" here, but manual mode must ignore it.
        location: FakeLocationService(fixed: const Coordinates(90, 90)),
        notifications: FakeNotificationService(),
        activeLocation: activeLocation,
      );

      final result = await pipeline.process(d);

      expect(result.distanceKm, closeTo(0, 0.01));
      expect(result.level, AlertLevel.critical);

      pipeline.dispose();
      await db.close();
    });
  });
}

class _FakeSource implements DisasterSource {
  _FakeSource(this.sourceId, {this.incidents = const [], this.error});

  final String sourceId;
  final List<Disaster> incidents;
  final Object? error;

  @override
  String get id => sourceId;

  @override
  String get name => 'Fake $sourceId';

  @override
  String get description => 'Test double';

  @override
  Future<SourceFetchResult> fetch({
    DateTime? since,
    Coordinates? referencePoint,
  }) async {
    if (error != null) {
      throw error!;
    }
    return SourceFetchResult(
      sourceId: sourceId,
      incidents: incidents,
      fetchedAt: DateTime.now(),
    );
  }
}