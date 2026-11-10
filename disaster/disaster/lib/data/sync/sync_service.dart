import 'dart:async';

import 'package:disaster/core/config/app_config.dart';
import 'package:disaster/core/network/connectivity_service.dart';
import 'package:disaster/data/local/repositories/sync_queue_repository.dart';
import 'package:disaster/data/remote/api/disaster_api_service.dart';
import 'package:disaster/data/remote/repositories/disaster_remote_repository.dart';
import 'package:disaster/data/sync/sync_metadata_store.dart';
import 'package:disaster/domain/entities/disaster.dart';
import 'package:disaster/domain/repositories/disaster_repository.dart';
import 'package:disaster/domain/repositories/shelter_repository.dart';
import 'package:disaster/domain/repositories/sos_event_repository.dart';
import 'package:disaster/domain/entities/sos_event.dart';
import 'package:disaster/data/remote/repositories/shelter_remote_repository.dart';
import 'package:disaster/domain/entities/shelter.dart';

enum SyncStatus { idle, pushing, pulling, done, error }

class SyncResult {
  SyncResult({
    this.pushedOutbox = 0,
    this.pulledDisasters = 0,
    this.pulledShelters = 0,
    this.error,
  });
  final int pushedOutbox;
  final int pulledDisasters;
  final int pulledShelters;
  final String? error;
}

/// Offline-first synchronization:
/// 1) push queued outbox items (SOS, acknowledgements) when online
/// 2) pull disasters updated since the last sync watermark (REST fallback /
///    catch-up after a WebSocket outage)
/// 3) pull nearby shelters
///
/// Runs on connectivity restoration and on a periodic timer.
class SyncService {
  SyncService({
    required this._connectivity,
    required this._syncQueue,
    required disasterRemote,
    required shelterRemote,
    required this._disasters,
    required this._shelters,
    required this._sosEvents,
    required this._api,
    required this._metadata,
  }) : _disasterRemote = disasterRemote,
       _shelterRemote = shelterRemote;

  final ConnectivityService _connectivity;
  final SyncQueueRepository _syncQueue;
  final DisasterRemoteRepository _disasterRemote;
  final ShelterRemoteRepository _shelterRemote;
  final DisasterRepository _disasters;
  final ShelterRepository _shelters;
  final SosEventRepository _sosEvents;
  final DisasterApiService _api;
  final SyncMetadataStore _metadata;

  static const String _watermarkKey = 'sync.last_sync_at';

  Timer? _periodic;
  StreamSubscription<bool>? _connectivitySub;

  final _statusController = StreamController<SyncStatus>.broadcast();
  final _resultController = StreamController<SyncResult>.broadcast();

  Stream<SyncStatus> get status => _statusController.stream;
  Stream<SyncResult> get results => _resultController.stream;
  SyncStatus _status = SyncStatus.idle;

  bool _running = false;

  /// Starts listening for connectivity changes and schedules periodic sync.
  void start({bool periodic = true}) {
    _connectivitySub ??= _connectivity.onChanged.listen((online) {
      if (online) {
        run();
      }
    });
    if (periodic) {
      _periodic ??= Timer.periodic(
        Duration(seconds: AppConfig.pollIntervalSeconds * 2),
        (_) {
          if (_connectivity.isOnline) run();
        },
      );
    }
    if (_connectivity.isOnline) run();
  }

  Future<SyncResult> run() async {
    if (_running) return SyncResult(error: 'already_running');
    _running = true;
    _setStatus(SyncStatus.pushing);
    try {
      final pushed = await _pushOutbox();
      _setStatus(SyncStatus.pulling);
      final disasters = await _pullDisasters();
      List<Shelter> shelters = const [];
      try {
        shelters = await _shelterRemote.fetchShelters();
        if (shelters.isNotEmpty) {
          await _shelters.upsertAll(shelters);
        }
      } catch (e) {
        // Shelter sync failure is non-fatal.
      }
      final result = SyncResult(
        pushedOutbox: pushed,
        pulledDisasters: disasters.length,
        pulledShelters: shelters.length,
      );
      _setStatus(SyncStatus.done);
      _resultController.add(result);
      return result;
    } catch (e) {
      _setStatus(SyncStatus.error);
      _resultController.add(SyncResult(error: e.toString()));
      return SyncResult(error: e.toString());
    } finally {
      _running = false;
    }
  }

  Future<int> _pushOutbox() async {
    final items = await _syncQueue.pending(limit: 50);
    var pushed = 0;
    for (final item in items) {
      try {
        if (item.entityType == 'sos') {
          final all = await _sosEvents.getAll();
          final event = all.where((e) => e.id == item.entityId).firstOrNull;
          if (event != null) {
            await _api.publishSos(event);
            await _sosEvents.updateStatus(event.id, SosStatus.sent);
          }
        } else if (item.entityType == 'ack') {
          await _api.acknowledgeAlerts([
            {'disaster_id': item.entityId ?? '', 'status': item.operation},
          ]);
        }
        await _syncQueue.markDone(item.id!);
        pushed++;
      } catch (e) {
        await _syncQueue.markFailed(item.id!, e.toString());
      }
    }
    return pushed;
  }

  Future<List<Disaster>> _pullDisasters() async {
    final sinceRaw = await _metadata.read(_watermarkKey);
    DateTime? since;
    if (sinceRaw != null) {
      final parsed = DateTime.tryParse(sinceRaw);
      if (parsed != null) {
        since = parsed;
      }
    }
    final now = DateTime.now().toUtc();
    final fetched = await _disasterRemote.fetchDisasters(since: since);
    if (fetched.isNotEmpty) {
      await _disasters.upsertAll(fetched);
    }
    await _metadata.write(_watermarkKey, now.toIso8601String());
    return fetched;
  }

  /// Watermark exposed for tests.
  Future<DateTime?> lastSync() async {
    final raw = await _metadata.read(_watermarkKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  void _setStatus(SyncStatus s) {
    if (_status != s) {
      _status = s;
      if (!_statusController.isClosed) _statusController.add(s);
    }
  }

  void dispose() {
    _periodic?.cancel();
    _connectivitySub?.cancel();
    _statusController.close();
    _resultController.close();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
