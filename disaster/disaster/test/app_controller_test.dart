import 'package:flutter_test/flutter_test.dart';

import 'package:disaster/domain/entities/disaster.dart';
import 'package:disaster/domain/entities/location_record.dart';
import 'package:disaster/domain/enums/disaster_status.dart';
import 'package:disaster/domain/enums/disaster_type.dart';
import 'package:disaster/domain/enums/severity.dart';
import 'package:disaster/domain/value_objects/coordinates.dart';
import 'package:disaster/presentation/providers/alerts_controller.dart';
import 'package:disaster/presentation/providers/app_controller.dart';
import 'package:disaster/presentation/providers/app_dependencies.dart';
import 'package:disaster/presentation/providers/location_controller.dart';

import 'helpers/fakes.dart';
import 'helpers/test_db.dart';

Future<AppDependencies> _boot() async {
  final db = await openTestDatabase();
  return AppDependencies.bootstrap(
    dbOverride: db,
    connectivityOverride: FakeConnectivityService(online: true),
    locationOverride: FakeLocationService(
      fixed: const Coordinates(21.17, 72.83),
    ),
    notificationsOverride: FakeNotificationService(),
    apiServiceOverride: FakeApiService(),
    wsUrl: 'invalid',
  );
}

Future<void> _waitForInit(AppController app) async {
  for (var i = 0; i < 200 && app.initializing; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  group('AppController location modes', () {
    late AppDependencies deps;
    late AppController app;
    late LocationController location;

    setUp(() async {
      deps = await _boot();
      location = LocationController(deps: deps);
      app = AppController(deps: deps, locationController: location);
      await _waitForInit(app);
    });

    tearDown(() async {
      app.dispose();
      location.dispose();
      deps.dispose();
    });

    test('starts in GPS mode with a persisted manual choice', () async {
      final record = LocationRecord(
        id: 'manual-home',
        label: 'Test City',
        coordinates: const Coordinates(18.5, 73.9),
        mode: LocationMode.manual,
      );
      await app.selectManualLocation(record);

      expect(app.settings.locationMode, LocationMode.manual);
      expect(app.settings.selectedLocationId, 'manual-home');
      expect(location.isManualMode, isTrue);
      expect(location.locationLabel, contains('Test City'));
      expect(location.manualLocation?.id, 'manual-home');

      final selected = await deps.locations.getSelected();
      expect(selected?.id, 'manual-home');
      expect(selected?.isSelected, isTrue);
    });

    test('switching back to GPS clears the manual selection', () async {
      final record = LocationRecord(
        id: 'manual-home',
        label: 'Test City',
        coordinates: const Coordinates(18.5, 73.9),
        mode: LocationMode.manual,
      );
      await app.selectManualLocation(record);
      await app.useGps();

      expect(app.settings.locationMode, LocationMode.gps);
      expect(app.settings.selectedLocationId, isNull);
      expect(location.isManualMode, isFalse);
      expect(await deps.locations.getSelected(), isNull);
      expect((await deps.locations.getAll()).single.isSelected, isFalse);
    });
  });

  group('AlertsController sections and filters', () {
    late AppDependencies deps;
    late LocationController location;
    late AlertsController alerts;

    setUp(() async {
      deps = await _boot();
      location = LocationController(deps: deps);
      // Anchor the reference point on the fixed fake GPS location.
      deps.activeLocation.updateGps(const Coordinates(21.17, 72.83));
      alerts = AlertsController(
        deps: deps,
        locationController: location,
      );
      await alerts.refresh();
    });

    tearDown(() async {
      alerts.dispose();
      location.dispose();
      deps.dispose();
    });

    Disaster at({
      required String id,
      required double lat,
      required double lng,
      Severity severity = Severity.moderate,
      required DisasterType type,
      DateTime? updatedAt,
    }) {
      return Disaster(
        id: id,
        type: type,
        title: id,
        coordinates: Coordinates(lat, lng),
        affectedRadiusKm: 20,
        severity: severity,
        status: DisasterStatus.active,
        updatedAt: updatedAt ?? DateTime.now(),
        provider: DataProvider.server,
      );
    }

    test('sections filter loaded active alerts', () async {
      // ~2.2 km from the reference point (21.17, 72.83) => close.
      await deps.disasters.upsert(
        at(
          id: 'quake-close',
          lat: 21.19,
          lng: 72.83,
          type: DisasterType.earthquake,
          severity: Severity.severe,
        ),
      );
      // ~110 km away => outside the default 25 km alert radius.
      await deps.disasters.upsert(
        at(
          id: 'flood-far',
          lat: 22.0,
          lng: 72.83,
          type: DisasterType.flood,
          severity: Severity.moderate,
        ),
      );
      // Old: outside the 24h recent window.
      await deps.disasters.upsert(
        at(
          id: 'fire-old',
          lat: 21.17,
          lng: 72.83,
          type: DisasterType.wildfire,
          severity: Severity.severe,
          updatedAt: DateTime.now().subtract(const Duration(days: 3)),
        ),
      );

      await alerts.refresh();
      expect(alerts.allItems.length, 3);

      alerts.setSection(AlertsController.sectionNearby);
      await alerts.refresh();
      expect(alerts.items.map((i) => i.disaster.id), contains('quake-close'));
      expect(alerts.items.map((i) => i.disaster.id), isNot(contains('flood-far')));

      alerts.setSection(AlertsController.sectionCritical);
      await alerts.refresh();
      expect(
        alerts.items.map((i) => i.disaster.id),
        isNot(contains('flood-far')),
      );

      alerts.setSection(AlertsController.sectionRecent);
      await alerts.refresh();
      expect(alerts.items.map((i) => i.disaster.id), isNot(contains('fire-old')));

      alerts.setSection(AlertsController.sectionAll);
      await alerts.refresh();
      expect(alerts.items.length, 3);
    });

    test('severity, distance and recency filters narrow the list', () async {
      await deps.disasters.upsert(
        at(
          id: 'near-severe',
          lat: 21.19,
          lng: 72.83,
          type: DisasterType.earthquake,
          severity: Severity.severe,
        ),
      );
      await deps.disasters.upsert(
        at(
          id: 'near-moderate',
          lat: 21.19,
          lng: 72.84,
          type: DisasterType.flood,
          severity: Severity.moderate,
        ),
      );

      alerts.setSection(AlertsController.sectionAll);
      await alerts.refresh();
      alerts.setSeverityFilter(Severity.severe);
      await alerts.refresh();
      expect(alerts.items, hasLength(1));
      expect(alerts.items.single.disaster.id, 'near-severe');

      alerts.setSeverityFilter(null);
      alerts.setMaxDistanceKm(1);
      await alerts.refresh();
      // Both are ~1.1 km out => filtered by the 1 km cap.
      expect(alerts.items, isEmpty);

      alerts.setMaxDistanceKm(5);
      await alerts.refresh();
      expect(alerts.items, hasLength(2));

      alerts.setDateFilter(
        DateTime.now().subtract(const Duration(hours: 1)),
      );
      await alerts.refresh();
      expect(alerts.items, hasLength(2));

      alerts.clearFilters();
      await alerts.refresh();
      expect(alerts.hasFilters, isFalse);
    });

    test('type filter narrows the list to one disaster type', () async {
      await deps.disasters.upsert(
        at(
          id: 'only-quake',
          lat: 21.17,
          lng: 72.83,
          type: DisasterType.earthquake,
        ),
      );
      await deps.disasters.upsert(
        at(
          id: 'only-flood',
          lat: 21.17,
          lng: 72.83,
          type: DisasterType.flood,
        ),
      );

      alerts.setSection(AlertsController.sectionAll);
      await alerts.refresh();
      expect(alerts.items, hasLength(2));

      alerts.toggleTypeFilter(DisasterType.earthquake);
      await alerts.refresh();
      expect(alerts.hasTypeFilter, isTrue);
      expect(alerts.items.map((i) => i.disaster.id), ['only-quake']);

      alerts.clearTypeFilter();
      await alerts.refresh();
      expect(alerts.hasTypeFilter, isFalse);
      expect(alerts.items, hasLength(2));
    });

    test('sectionFrom normalizes unknown section ids to all', () {
      expect(AlertsController.sectionFrom('recent'), 'recent');
      expect(AlertsController.sectionFrom('critical'), 'critical');
      expect(AlertsController.sectionFrom('nonsense'), AlertsController.sectionAll);
    });
  });
}