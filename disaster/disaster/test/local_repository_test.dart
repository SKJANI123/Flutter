import 'package:flutter_test/flutter_test.dart';

import 'package:disaster/data/local/database/app_database.dart';
import 'package:disaster/data/local/repositories/alert_history_repository.dart';
import 'package:disaster/data/local/repositories/disaster_repository.dart';
import 'package:disaster/data/local/repositories/emergency_contact_repository.dart';
import 'package:disaster/data/local/repositories/settings_repository.dart';
import 'package:disaster/data/local/repositories/shelter_repository.dart';
import 'package:disaster/data/local/repositories/sos_event_repository.dart';
import 'package:disaster/data/local/repositories/sync_queue_repository.dart';
import 'package:disaster/domain/entities/alert_history_entry.dart';
import 'package:disaster/domain/entities/emergency_contact.dart';
import 'package:disaster/domain/entities/shelter.dart';
import 'package:disaster/domain/entities/sos_event.dart';
import 'package:disaster/domain/enums/alert_level.dart';
import 'package:disaster/domain/enums/disaster_status.dart';
import 'package:disaster/domain/enums/disaster_type.dart';
import 'package:disaster/domain/value_objects/coordinates.dart';

import 'helpers/test_db.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await openTestDatabase();
  });

  tearDown(() => db.close());

  group('LocalDisasterRepository', () {
    test(
      'upsert inserts then replaces the same id without duplicates',
      () async {
        final repo = LocalDisasterRepository(db);
        final d1 = makeDisaster(id: 'dupe-1');
        await repo.upsert(d1);
        final d2 = d1.copyWith(title: 'Updated severity');
        await repo.upsert(d2);

        expect(await repo.count(), 1);
        final stored = await repo.findById('dupe-1');
        expect(stored!.title, 'Updated severity');

        final all = await repo.findAll(onlyActive: false);
        expect(all, hasLength(1));
      },
    );

    test('upsertAll persists a batch', () async {
      final repo = LocalDisasterRepository(db);
      await repo.upsertAll([
        makeDisaster(id: 'b1'),
        makeDisaster(id: 'b2'),
        makeDisaster(id: 'b1', title: 'Replaced'),
      ]);
      expect(await repo.count(), 2);
      expect((await repo.findById('b1'))!.title, 'Replaced');
    });

    test('findAll only returns active by default', () async {
      final repo = LocalDisasterRepository(db);
      await repo.upsertAll([
        makeDisaster(id: 'act-1'),
        makeDisaster(id: 'res-1', status: DisasterStatus.resolved),
        makeDisaster(id: 'exp-1', status: DisasterStatus.expired),
      ]);
      final active = await repo.findAll();
      expect(active.map((d) => d.id), ['act-1']);
    });

    test('findAll filters by type', () async {
      final repo = LocalDisasterRepository(db);
      await repo.upsertAll([
        makeDisaster(id: 't1', type: DisasterType.earthquake),
        makeDisaster(id: 't2', type: DisasterType.flood),
      ]);
      final quakes = await repo.findAll(types: [DisasterType.earthquake]);
      expect(quakes.map((d) => d.id), ['t1']);
    });

    test('findByProvider isolates simulator from server data', () async {
      final repo = LocalDisasterRepository(db);
      await repo.upsert(makeDisaster(id: 'server-1'));
      await repo.upsert(
        makeDisaster(id: 'sim-1', provider: DataProvider.simulator),
      );
      final server = await repo.findByProvider(DataProvider.server.value);
      final sim = await repo.findByProvider(DataProvider.simulator.value);
      expect(server.single.id, 'server-1');
      expect(sim.single.id, 'sim-1');
    });

    test('clearSimulatorData keeps server data', () async {
      final repo = LocalDisasterRepository(db);
      await repo.upsert(makeDisaster(id: 'server-keep'));
      await repo.upsert(
        makeDisaster(id: 'sim-remove', provider: DataProvider.simulator),
      );
      await repo.clearSimulatorData();
      expect(await repo.findById('sim-remove'), isNull);
      expect(await repo.findById('server-keep'), isNotNull);
    });

    test('deleteOlderThan only removes expired/resolved rows', () async {
      final repo = LocalDisasterRepository(db);
      final past = DateTime.now().subtract(const Duration(days: 10));
      await repo.upsert(
        makeDisaster(
          id: 'old-resolved',
          status: DisasterStatus.resolved,
        ).copyWith(expiresAt: past),
      );
      await repo.upsert(
        makeDisaster(
          id: 'old-expired',
          status: DisasterStatus.expired,
        ).copyWith(expiresAt: past),
      );
      await repo.upsert(
        makeDisaster(
          id: 'active-keep',
        ).copyWith(expiresAt: DateTime.now().subtract(const Duration(days: 3))),
      );
      await repo.deleteOlderThan(
        DateTime.now().subtract(const Duration(days: 5)),
      );
      expect(await repo.findById('old-resolved'), isNull);
      expect(await repo.findById('old-expired'), isNull);
      expect(await repo.findById('active-keep'), isNotNull);
    });

    test('deleteById removes a single row', () async {
      final repo = LocalDisasterRepository(db);
      await repo.upsert(makeDisaster(id: 'gone'));
      await repo.deleteById('gone');
      expect(await repo.findById('gone'), isNull);
    });

    test('findById returns null for unknown ids', () async {
      final repo = LocalDisasterRepository(db);
      expect(await repo.findById('nope'), isNull);
    });
  });

  group('LocalSettingsRepository', () {
    test('returns defaults when empty', () async {
      final repo = LocalSettingsRepository(db);
      final s = await repo.load();
      expect(s.alertRadiusKm, 25.0);
      expect(s.notificationsEnabled, isTrue);
      expect(s.onboardingCompleted, isFalse);
    });

    test('save then load round-trips fields', () async {
      final repo = LocalSettingsRepository(db);
      final updated = (await repo.load()).copyWith(
        alertRadiusKm: 50,
        notificationsEnabled: false,
        selectedDisasterTypes: const {'earthquake'},
      );
      await repo.save(updated);

      final loaded = await repo.load();
      expect(loaded.alertRadiusKm, 50);
      expect(loaded.notificationsEnabled, isFalse);
      expect(loaded.selectedDisasterTypes, {'earthquake'});
    });

    test('setOnboardingCompleted persists', () async {
      final repo = LocalSettingsRepository(db);
      await repo.setOnboardingCompleted(true);
      expect((await repo.load()).onboardingCompleted, isTrue);
    });
  });

  group('LocalEmergencyContactRepository', () {
    test('insert, update and delete round-trip', () async {
      final repo = LocalEmergencyContactRepository(db);
      final c = EmergencyContact(
        id: 'c1',
        name: 'Alice',
        phone: '+1 555',
        relationship: 'sister',
        isPrimary: true,
      );
      await repo.insert(c);
      expect((await repo.getAll()).single.name, 'Alice');

      await repo.update(c.copyWith(name: 'Alice R.', isVerified: true));
      final updated = await repo.getById('c1');
      expect(updated!.name, 'Alice R.');
      expect(updated.isVerified, isTrue);

      await repo.deleteById('c1');
      expect(await repo.getAll(), isEmpty);
    });

    test('getPrimaryContacts only returns primary contacts', () async {
      final repo = LocalEmergencyContactRepository(db);
      await repo.insert(
        const EmergencyContact(
          id: 'p1',
          name: 'P',
          phone: '1',
          isPrimary: true,
        ),
      );
      await repo.insert(
        const EmergencyContact(id: 'n1', name: 'N', phone: '2'),
      );
      final primaries = await repo.getPrimaryContacts();
      expect(primaries.map((c) => c.id), ['p1']);
    });
  });

  group('LocalShelterRepository', () {
    test('upsertAll then getAll returns every shelter', () async {
      final repo = LocalShelterRepository(db);
      await repo.upsertAll([
        const Shelter(
          id: 's1',
          name: 'Hall A',
          coordinates: Coordinates(1, 2),
          type: SafePlaceType.reliefCamp,
          capacity: 100,
        ),
        const Shelter(id: 's2', name: 'Hall B', coordinates: Coordinates(3, 4)),
      ]);
      final all = await repo.getAll();
      expect(all, hasLength(2));
      expect(await repo.getById('s1'), isNotNull);
      expect(all.any((s) => s.type == SafePlaceType.reliefCamp), isTrue);
    });

    test('upsert replaces duplicate ids', () async {
      final repo = LocalShelterRepository(db);
      await repo.upsertAll([
        const Shelter(id: 's1', name: 'Old', coordinates: Coordinates(0, 0)),
      ]);
      await repo.upsert(
        const Shelter(id: 's1', name: 'New', coordinates: Coordinates(0, 0)),
      );
      expect((await repo.getById('s1'))!.name, 'New');
    });

    test('deleteById removes a shelter', () async {
      final repo = LocalShelterRepository(db);
      await repo.upsert(
        const Shelter(id: 's1', name: 'Gone', coordinates: Coordinates(0, 0)),
      );
      await repo.deleteById('s1');
      expect(await repo.getAll(), isEmpty);
    });
  });

  group('LocalSosEventRepository', () {
    test('insert and getAll round-trip with status', () async {
      final repo = LocalSosEventRepository(db);
      const event = SosEvent(
        id: 'sos-1',
        latitude: 12.0,
        longitude: 34.0,
        message: 'help',
      );
      await repo.insert(event);
      final all = await repo.getAll();
      expect(all.single.id, 'sos-1');
      expect(all.single.status, SosStatus.pending);
    });

    test('getNeedingSync returns pending and queued only', () async {
      final repo = LocalSosEventRepository(db);
      await repo.insert(
        const SosEvent(id: 'pending-1', latitude: 0, longitude: 0),
      );
      await repo.insert(
        const SosEvent(
          id: 'queued-1',
          latitude: 0,
          longitude: 0,
          status: SosStatus.queued,
        ),
      );
      await repo.insert(
        const SosEvent(
          id: 'sent-1',
          latitude: 0,
          longitude: 0,
          status: SosStatus.sent,
        ),
      );
      final needing = await repo.getNeedingSync();
      expect(needing.map((e) => e.id).toSet(), {'pending-1', 'queued-1'});
    });

    test('updateStatus moves an event out of needing-sync', () async {
      final repo = LocalSosEventRepository(db);
      await repo.insert(const SosEvent(id: 'sos-2', latitude: 0, longitude: 0));
      await repo.updateStatus('sos-2', SosStatus.sent);
      expect(await repo.getNeedingSync(), isEmpty);
      expect((await repo.getAll()).single.status, SosStatus.sent);
    });
  });

  group('LocalAlertHistoryRepository', () {
    test(
      'insert generates an id and latestForDisaster returns newest',
      () async {
        final disasters = LocalDisasterRepository(db);
        await disasters.upsert(makeDisaster(id: 'h1'));
        final repo = LocalAlertHistoryRepository(db);
        await repo.insert(
          AlertHistoryEntry(
            id: '',
            disasterId: 'h1',
            newLevel: AlertLevel.warning,
            triggeredAt: DateTime.now().subtract(const Duration(minutes: 2)),
          ),
        );
        await repo.insert(
          AlertHistoryEntry(
            id: '',
            disasterId: 'h1',
            previousLevel: AlertLevel.warning,
            newLevel: AlertLevel.danger,
            triggeredAt: DateTime.now(),
          ),
        );
        final latest = await repo.latestForDisaster('h1');
        expect(latest, isNotNull);
        expect(latest!.id, isNotEmpty);
        expect(latest.newLevel, AlertLevel.danger);
        expect(latest.previousLevel, AlertLevel.warning);
        expect(latest.disaster, isNotNull);
      },
    );

    test('updateNotificationStatus persists', () async {
      final disasters = LocalDisasterRepository(db);
      await disasters.upsert(makeDisaster(id: 'h2'));
      final repo = LocalAlertHistoryRepository(db);
      await repo.insert(
        AlertHistoryEntry(
          id: '',
          disasterId: 'h2',
          newLevel: AlertLevel.critical,
        ),
      );
      final latest = await repo.latestForDisaster('h2');
      await repo.updateNotificationStatus(latest!.id, status: 'sent');
      expect(
        (await repo.latestForDisaster('h2'))!.notificationStatus.code,
        'sent',
      );
    });

    test('getAll returns entries newest first', () async {
      final disasters = LocalDisasterRepository(db);
      await disasters.upsertAll([
        makeDisaster(id: 'h3'),
        makeDisaster(id: 'h4'),
      ]);
      final repo = LocalAlertHistoryRepository(db);
      await repo.insert(
        AlertHistoryEntry(
          id: '',
          disasterId: 'h3',
          newLevel: AlertLevel.safe,
          triggeredAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
      );
      await repo.insert(
        AlertHistoryEntry(
          id: '',
          disasterId: 'h4',
          newLevel: AlertLevel.critical,
          triggeredAt: DateTime.now(),
        ),
      );
      final all = await repo.getAll();
      expect(all, hasLength(2));
      expect(all.first.disasterId, 'h4');
    });
  });

  group('SyncQueueRepository', () {
    test('enqueue adds pending items and countPending reflects it', () async {
      final repo = SyncQueueRepository(db);
      await repo.enqueue(entityType: 'ack', entityId: 'd1', operation: 'ack');
      await repo.enqueue(entityType: 'sos', entityId: 'x', operation: 'push');
      expect(await repo.countPending(), 2);
      final pending = await repo.pending();
      expect(pending, hasLength(2));
      expect(pending.first.entityType, 'ack');
    });

    test('markDone removes the item from pending', () async {
      final repo = SyncQueueRepository(db);
      final id = await repo.enqueue(
        entityType: 'ack',
        entityId: 'd1',
        operation: 'ack',
      );
      await repo.markDone(id);
      expect(await repo.countPending(), 0);
    });

    test('markFailed increments attempts and flags failure', () async {
      final repo = SyncQueueRepository(db);
      final id = await repo.enqueue(
        entityType: 'sos',
        entityId: 'x',
        operation: 'push',
      );
      await repo.markFailed(id, 'offline');
      final rows = await db.db.query(
        'sync_queue',
        where: 'id = ?',
        whereArgs: [id],
      );
      expect(rows.single['status'], 'failed');
      expect(rows.single['attempts'], 1);
      expect(rows.single['error'], 'offline');
    });
  });
}
