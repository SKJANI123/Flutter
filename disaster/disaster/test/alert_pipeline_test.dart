import 'package:flutter_test/flutter_test.dart';

import 'package:disaster/data/local/database/app_database.dart';
import 'package:disaster/data/local/repositories/alert_history_repository.dart';
import 'package:disaster/data/local/repositories/disaster_repository.dart';
import 'package:disaster/data/local/repositories/settings_repository.dart';
import 'package:disaster/domain/enums/alert_level.dart';
import 'package:disaster/domain/enums/disaster_type.dart';
import 'package:disaster/domain/enums/severity.dart';
import 'package:disaster/domain/services/alert_pipeline.dart';
import 'package:disaster/domain/value_objects/coordinates.dart';

import 'helpers/fakes.dart';
import 'helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late LocalDisasterRepository disasters;
  late LocalAlertHistoryRepository history;
  late LocalSettingsRepository settings;

  setUp(() async {
    db = await openTestDatabase();
    disasters = LocalDisasterRepository(db);
    history = LocalAlertHistoryRepository(db);
    settings = LocalSettingsRepository(db);
  });

  tearDown(() => db.close());

  AlertPipeline buildPipeline({
    Coordinates? userLocation,
    FakeNotificationService? notifications,
  }) {
    return AlertPipeline(
      disasters: disasters,
      history: history,
      settings: settings,
      location: FakeLocationService(fixed: userLocation),
      notifications: notifications ?? FakeNotificationService(),
    );
  }

  group('AlertPipeline.validate', () {
    test('persists processed events to SQLite', () async {
      final d = makeDisaster(id: 'pipe-1');
      final pipeline = buildPipeline(userLocation: const Coordinates(0, 0));
      final result = await pipeline.process(d);

      expect(result.skipped, isFalse);
      expect(await disasters.findById('pipe-1'), isNotNull);
    });

    test('skips duplicate fingerprints of the same event', () async {
      final d = makeDisaster(id: 'pipe-dupe');
      final pipeline = buildPipeline(userLocation: const Coordinates(0, 0));

      final first = await pipeline.process(d);
      final second = await pipeline.process(d);

      expect(first.skipped, isFalse);
      expect(second.skippedReason, 'duplicate');
    });

    test('skips events whose disaster type is turned off', () async {
      await settings.save(
        (await settings.load()).copyWith(
          selectedDisasterTypes: const {'storm'},
        ),
      );
      final d = makeDisaster(id: 'pipe-off', type: DisasterType.earthquake);
      final pipeline = buildPipeline(userLocation: const Coordinates(0, 0));

      final result = await pipeline.process(d);
      expect(result.skippedReason, 'type_disabled');
      expect(await disasters.findById('pipe-off'), isNull);
    });
  });

  group('AlertPipeline.ratingAndHistory', () {
    test(
      'event at the user location is critical, notified and recorded',
      () async {
        final notifications = FakeNotificationService();
        final d = makeDisaster(
          id: 'pipe-critical',
          lat: 0.0,
          lng: 0.0,
          radiusKm: 10,
          severity: Severity.extreme,
        );
        final pipeline = buildPipeline(
          userLocation: const Coordinates(0, 0),
          notifications: notifications,
        );

        final result = await pipeline.process(d);

        expect(result.level, AlertLevel.critical);
        expect(result.distanceKm, closeTo(0, 0.01));
        expect(result.notified, isTrue);
        expect(notifications.shown, isNotEmpty);
        expect(notifications.shown.single, contains('CRITICAL:'));

        final latest = await history.latestForDisaster('pipe-critical');
        expect(latest!.newLevel, AlertLevel.critical);
        expect(latest.notificationStatus.code, 'sent');
      },
    );

    test('level evolves and records changes in history', () async {
      final pipeline = buildPipeline(userLocation: const Coordinates(0, 0));

      // Far away -> warning (minimumAlertLevel floor = 1).
      final t0 = DateTime.now();
      final far = makeDisaster(
        id: 'pipe-far',
        lat: 10,
        lng: 0,
        radiusKm: 1,
      ).copyWith(updatedAt: t0);
      final farResult = await pipeline.process(far);
      expect(farResult.level, AlertLevel.warning);

      // Then the same event moves next to the user -> danger.
      final near = makeDisaster(
        id: 'pipe-far',
        lat: 0.0,
        lng: 0.003,
        radiusKm: 1,
      ).copyWith(updatedAt: t0.add(const Duration(seconds: 1)));
      final nearResult = await pipeline.process(near);
      expect(nearResult.level, AlertLevel.danger);

      final entries = await history.getAll();
      expect(entries, hasLength(2));
      expect(entries.first.newLevel, AlertLevel.danger);
      expect(entries.first.previousLevel, AlertLevel.warning);
    });

    test('notifications are suppressed when disabled', () async {
      await settings.save(
        (await settings.load()).copyWith(notificationsEnabled: false),
      );
      final notifications = FakeNotificationService();
      final d = makeDisaster(
        id: 'pipe-quiet',
        lat: 0.0,
        lng: 0.0,
        radiusKm: 10,
      );
      final pipeline = buildPipeline(
        userLocation: const Coordinates(0, 0),
        notifications: notifications,
      );

      final result = await pipeline.process(d);

      expect(result.level, AlertLevel.critical);
      expect(result.notified, isFalse);
      expect(notifications.shown, isEmpty);
      expect(
        (await history.latestForDisaster('pipe-quiet'))!
            .notificationStatus
            .code,
        'suppressed',
      );
    });

    test(
      'minimumAlertLevel raises safe events to the configured floor',
      () async {
        await settings.save(
          (await settings.load()).copyWith(minimumAlertLevel: 2),
        );
        final d = makeDisaster(
          id: 'pipe-floor',
          lat: 20,
          lng: 0,
          radiusKm: 1,
          severity: Severity.minor,
        );
        final pipeline = buildPipeline(userLocation: const Coordinates(0, 0));

        final result = await pipeline.process(d);

        expect(result.level, AlertLevel.danger);
      },
    );

    test('processAll handles a batch sequentially', () async {
      final pipeline = buildPipeline(userLocation: const Coordinates(0, 0));
      final events = [
        makeDisaster(id: 'batch-1', lat: 0, lng: 0),
        makeDisaster(id: 'batch-2', lat: 0, lng: 0),
      ];

      final results = await pipeline.processAll(events);

      expect(results, hasLength(2));
      expect(await disasters.count(), 2);
    });
  });
}
