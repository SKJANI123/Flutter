import 'dart:async';

import 'package:disaster/core/config/app_config.dart';
import 'package:disaster/core/network/connectivity_service.dart';
import 'package:disaster/data/sources/disaster_source.dart';
import 'package:disaster/data/sources/gdacs_source.dart';
import 'package:disaster/data/sources/open_meteo_weather_source.dart';
import 'package:disaster/data/sources/source_config.dart';
import 'package:disaster/data/sources/source_health.dart';
import 'package:disaster/data/sources/usgs_earthquake_source.dart';
import 'package:disaster/data/sync/sync_metadata_store.dart';
import 'package:disaster/domain/services/active_location.dart';
import 'package:disaster/domain/services/alert_pipeline.dart';

/// Outcome of one ingestion pass across all configured sources.
class IngestResult {
  const IngestResult({
    this.refreshed = 0,
    this.failed = 0,
    this.incidents = 0,
    this.erroredSources = const [],
  });

  final int refreshed;
  final int failed;
  final int incidents;
  final List<String> erroredSources;

  bool get allHealthy => failed == 0;
}

/// Polls the real, authoritative incident feeds (USGS, GDACS, national
/// weather models) and pushes every incident through the single [AlertPipeline]
/// — the same code path used by WebSocket/REST and the simulator — so saving,
/// deduping, radius-based leveling and critical notifications are identical.
///
/// Key behaviours:
///  * each source is fetched independently; a down source is recorded in
///    [health] and reported as *unavailable* — never faked;
///  * a per-source watermark avoids re-inserting old incidents;
///  * location-based sources use the user's active reference point (manual
///    mode works with no GPS);
///  * periodic refresh + refresh on connectivity restore.
class IncidentIngestionService {
  IncidentIngestionService({
    required this.health,
    required this.pipeline,
    required this.metadata,
    required this.activeLocation,
    required this.connectivity,
    List<DisasterSource>? sources,
    SourceConfig? config,
  }) : _sources = sources ?? _buildSources(config ?? SourceConfig.defaults);

  final SourceHealthRegistry health;
  final AlertPipeline pipeline;
  final SyncMetadataStore metadata;
  final ActiveLocation activeLocation;
  final ConnectivityService connectivity;

  final List<DisasterSource> _sources;
  static const String _watermarkPrefix = 'source.';

  Timer? _periodic;
  StreamSubscription<bool>? _connectivitySub;
  bool _running = false;

  final _resultsController = StreamController<IngestResult>.broadcast();
  Stream<IngestResult> get results => _resultsController.stream;

  /// Builds the bundled official feeds from [SourceConfig].
  static List<DisasterSource> _buildSources(SourceConfig config) {
    final out = <DisasterSource>[];
    for (final s in config.enabled) {
      switch (s.id) {
        case 'usgs':
          out.add(UsgsEarthquakeSource(config: s));
        case 'gdacs':
          out.add(GdacsSource(config: s));
        case 'open_meteo_weather':
          out.add(OpenMeteoWeatherSource(config: s));
        default:
          break;
      }
    }
    return out;
  }

  /// Registers sources with the health registry.
  void registerSources() {
    for (final s in _sources) {
      health.register(s);
    }
  }

  void start({bool periodic = true}) {
    registerSources();
    _connectivitySub ??= connectivity.onChanged.listen((online) {
      if (online) refresh();
    });
    if (periodic) {
      _periodic ??= Timer.periodic(
        Duration(seconds: AppConfig.ingestIntervalSeconds),
        (_) {
          if (connectivity.isOnline) refresh();
        },
      );
    }
    if (connectivity.isOnline) refresh();
  }

  /// Runs one ingestion pass. Never throws; per-source errors are recorded.
  Future<IngestResult> refresh() async {
    if (_running) return IngestResult();
    _running = true;
    try {
      var refreshed = 0;
      var failed = 0;
      var incidents = 0;
      final errors = <String>[];
      for (final source in _sources) {
        try {
          final since = await _readWatermark(source.id);
          final result = await source.fetch(
            since: since,
            referencePoint: activeLocation.active,
          );
          await pipeline.processAll(result.incidents);
          incidents += result.incidents.length;
          await _writeWatermark(source.id, DateTime.now().toUtc());
          health.markSuccess(source.id, result.incidents.length);
          refreshed++;
        } on SourceUnavailableException catch (e) {
          failed++;
          errors.add(e.sourceId);
          health.markFailure(source.id, e);
        } on Object catch (e) {
          failed++;
          errors.add(source.id);
          health.markFailure(source.id, e);
        }
      }
      final out = IngestResult(
        refreshed: refreshed,
        failed: failed,
        incidents: incidents,
        erroredSources: errors,
      );
      if (!_resultsController.isClosed) _resultsController.add(out);
      return out;
    } finally {
      _running = false;
    }
  }

  /// Suspends periodic polling (used when the user disables live sources).
  void stop() {
    _periodic?.cancel();
    _periodic = null;
  }

  Future<DateTime?> _readWatermark(String sourceId) async {
    final raw = await metadata.read('$_watermarkPrefix$sourceId.last_sync_at');
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> _writeWatermark(String sourceId, DateTime utc) => metadata.write(
    '$_watermarkPrefix$sourceId.last_sync_at',
    utc.toIso8601String(),
  );

  /// Public for tests: resolves a source by id.
  DisasterSource? sourceById(String id) {
    for (final s in _sources) {
      if (s.id == id) return s;
    }
    return null;
  }

  void dispose() {
    stop();
    _connectivitySub?.cancel();
    _resultsController.close();
  }
}
