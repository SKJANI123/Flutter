import 'package:flutter_test/flutter_test.dart';

import 'package:disaster/data/local/database/app_database.dart';
import 'package:disaster/data/local/repositories/alert_history_repository.dart';
import 'package:disaster/data/local/repositories/disaster_repository.dart';
import 'package:disaster/data/local/repositories/settings_repository.dart';
import 'package:disaster/data/simulator/disaster_simulator.dart';
import 'package:disaster/domain/enums/alert_level.dart';
import 'package:disaster/domain/enums/disaster_status.dart';
import 'package:disaster/domain/services/alert_pipeline.dart';
import 'package:disaster/domain/value_objects/coordinates.dart';

import 'helpers/fakes.dart';
import 'helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late LocalDisasterRepository disasters;
  late AlertPipeline pipeline;
  late DisasterSimulator simulator;

  setUp(() async {
    db = await openTestDatabase();
    disasters = LocalDisasterRepository(db);
    pipeline = AlertPipeline(
      disasters: disasters,
      history: LocalAlertHistoryRepository(db),
      settings: LocalSettingsRepository(db),
      location: FakeLocationService(fixed: const Coordinates(0, 0)),
      notifications: FakeNotificationService(),
    );
    simulator = DisasterSimulator(
      pipeline: pipeline,
      disasters: disasters,
      centerLat: 0,
      centerLng: 0,
    );
  });

  tearDown(() {
    simulator.dispose();
    return db.close();
  });

  group('DisasterSimulator', () {
    test('is available in dev/test builds', () {
      expect(simulator.isDisabledInBuild, isFalse);
    });

    test('simulateOne persists an event tagged as simulator data', () async {
      final d = await simulator.simulateOne(id: 'sim-fixed');

      expect(d.id, 'sim-fixed');
      expect(d.provider, DataProvider.simulator);
      final stored = await disasters.findById('sim-fixed');
      expect(stored!.provider, DataProvider.simulator);
      expect(stored.status, DisasterStatus.active);
    });

    test('simulator data is excluded from the server alert feed', () async {
      await disasters.upsert(makeDisaster(id: 'real-1'));
      await simulator.simulateOne(id: 'sim-2');

      final server = await disasters.findByProvider(DataProvider.server.value);
      final simData = await disasters.findByProvider(
        DataProvider.simulator.value,
      );
      expect(server.map((d) => d.id), ['real-1']);
      expect(simData.single.id, 'sim-2');
    });

    test(
      'simulateCritical generates a critical-level event near the center',
      () async {
        final d = await simulator.simulateCritical();

        final latest = await LocalAlertHistoryRepository(db)
            .latestForDisaster(d.id);
        expect(latest, isNotNull);
        expect(latest!.newLevel, AlertLevel.critical);
      },
    );

    test('clearSimulatorData purges only simulator rows', () async {
      await disasters.upsert(makeDisaster(id: 'keep-server'));
      await simulator.simulateOne(id: 'drop-sim');

      await simulator.clearSimulatorData();

      expect(await disasters.findById('drop-sim'), isNull);
      expect(await disasters.findById('keep-server'), isNotNull);
    });

    test('simulateBurst generates the requested number of events', () async {
      final events = await simulator.simulateBurst(count: 2);
      expect(events, hasLength(2));
      expect(await disasters.count(), 2);
      final simData = await disasters.findByProvider(
        DataProvider.simulator.value,
      );
      expect(simData, hasLength(2));
    });
  });
}
