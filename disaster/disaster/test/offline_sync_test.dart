import 'package:flutter_test/flutter_test.dart';

import 'package:disaster/core/errors/exceptions.dart';
import 'package:disaster/data/local/database/app_database.dart';
import 'package:disaster/data/local/repositories/disaster_repository.dart';
import 'package:disaster/data/local/repositories/shelter_repository.dart';
import 'package:disaster/data/local/repositories/sos_event_repository.dart';
import 'package:disaster/data/local/repositories/sync_queue_repository.dart';
import 'package:disaster/data/remote/repositories/disaster_remote_repository.dart';
import 'package:disaster/data/remote/repositories/shelter_remote_repository.dart';
import 'package:disaster/data/sync/sync_metadata_store.dart';
import 'package:disaster/data/sync/sync_service.dart';
import 'package:disaster/domain/entities/disaster.dart';
import 'package:disaster/domain/entities/shelter.dart';
import 'package:disaster/domain/entities/sos_event.dart';
import 'package:disaster/domain/value_objects/coordinates.dart';

import 'helpers/fakes.dart';
import 'helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late LocalDisasterRepository disasters;
  late LocalShelterRepository shelters;
  late LocalSosEventRepository sosEvents;
  late SyncQueueRepository queue;
  late SyncMetadataStore metadata;
  late FakeApiService api;
  late SyncService sync;

  setUp(() async {
    db = await openTestDatabase();
    disasters = LocalDisasterRepository(db);
    shelters = LocalShelterRepository(db);
    sosEvents = LocalSosEventRepository(db);
    queue = SyncQueueRepository(db);
    metadata = SyncMetadataStore(db);
    api = FakeApiService();
    sync = SyncService(
      connectivity: makeConnectivityService(online: true),
      syncQueue: queue,
      disasterRemote: DisasterRemoteRepository(api),
      shelterRemote: ShelterRemoteRepository(api),
      disasters: disasters,
      shelters: shelters,
      sosEvents: sosEvents,
      api: api,
      metadata: metadata,
    );
  });

  tearDown(() {
    sync.dispose();
    return db.close();
  });

  group('SyncService.pull', () {
    test('fetches disasters and shelters and stores them locally', () async {
      api.disasters = [makeDisaster(id: 'pull-1')];
      api.shelters = [
        const Shelter(id: 's-1', name: 'Hall', coordinates: Coordinates(0, 0)),
      ];

      final result = await sync.run();

      expect(result.error, isNull);
      expect(result.pulledDisasters, 1);
      expect(result.pulledShelters, 1);
      expect(await disasters.findById('pull-1'), isNotNull);
      expect(await shelters.getById('s-1'), isNotNull);
      expect(await sync.lastSync(), isNotNull);
    });

    test('a shelter failure is non-fatal and disasters still sync', () async {
      api.disasters = [makeDisaster(id: 'pull-2')];
      api.sheltersError = const NetworkException('shelter outage');

      final result = await sync.run();

      expect(result.error, isNull);
      expect(result.pulledDisasters, 1);
      expect(result.pulledShelters, 0);
      expect(await disasters.findById('pull-2'), isNotNull);
    });

    test('a disaster pull failure surfaces as an error result', () async {
      api.disastersError = const NetworkException('offline');

      final result = await sync.run();

      expect(result.error, contains('offline'));
      expect(result.pulledDisasters, 0);
    });

    test('writing the watermark enables incremental pulls', () async {
      api.disasters = [makeDisaster(id: 'pull-3')];
      await sync.run();

      final since = await sync.lastSync();
      expect(since, isNotNull);
      // A second run without new events does not overwrite the existing data.
      api.disasters = <Disaster>[];
      await sync.run();
      expect(await disasters.findById('pull-3'), isNotNull);
    });
  });

  group('SyncService.outbox', () {
    test('pushes queued SOS events and marks them synced', () async {
      const event = SosEvent(
        id: 'sos-out-1',
        latitude: 5.0,
        longitude: 6.0,
        status: SosStatus.pending,
      );
      await sosEvents.insert(event);
      await queue.enqueue(
        entityType: 'sos',
        entityId: event.id,
        operation: 'push',
      );

      final result = await sync.run();

      expect(result.pushedOutbox, 1);
      expect(api.publishedSos.single.id, 'sos-out-1');
      expect(await queue.countPending(), 0);
      expect(await sosEvents.getNeedingSync(), isEmpty);
    });

    test('failed pushes mark the outbox item as failed', () async {
      await sosEvents.insert(
        const SosEvent(id: 'sos-fail', latitude: 0, longitude: 0),
      );
      await queue.enqueue(
        entityType: 'sos',
        entityId: 'sos-fail',
        operation: 'push',
      );
      api.failOutbox = true;

      final result = await sync.run();

      expect(result.pushedOutbox, 0);
      expect(api.publishedSos, isEmpty);
      expect(await queue.countPending(), 0);
      final rows = await db.db.query(
        'sync_queue',
        where: 'entity_id = ?',
        whereArgs: ['sos-fail'],
      );
      expect(rows.single['status'], 'failed');
      expect(rows.single['attempts'], 1);
      expect(await sosEvents.getNeedingSync(), hasLength(1));
    });

    test('acknowledgements are pushed through the API', () async {
      await queue.enqueue(
        entityType: 'ack',
        entityId: 'd-ack',
        operation: 'acked',
      );

      final result = await sync.run();

      expect(result.pushedOutbox, 1);
      expect(api.acks.single, {'disaster_id': 'd-ack', 'status': 'acked'});
    });
  });
}
