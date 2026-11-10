import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'package:disaster/core/config/app_config.dart';
import 'package:disaster/data/sources/disaster_source.dart';
import 'package:disaster/data/sources/region_scope.dart';
import 'package:disaster/data/sources/source_config.dart';
import 'package:disaster/domain/entities/disaster.dart';
import 'package:disaster/domain/enums/disaster_status.dart';
import 'package:disaster/domain/enums/disaster_type.dart';
import 'package:disaster/domain/enums/severity.dart';
import 'package:disaster/domain/value_objects/coordinates.dart';

/// Official U.S. Geological Survey earthquake feed (GeoJSON, keyless,
/// government-authoritative).
///
/// Endpoint overridable via `--dart-define=USGS_BASE_URL=...`.
class UsgsEarthquakeSource implements DisasterSource {
  UsgsEarthquakeSource({required this.config, http.Client? client})
    : _injectedClient = client;

  final SourceConfigEntry config;
  final http.Client? _injectedClient;

  @override
  String get id => config.id;

  @override
  String get name => config.name;

  @override
  String get description => config.description;

  double get minMagnitude => config.paramDouble('minMagnitude', 5.0);
  int get maxAgeHours => config.paramInt('maxAgeHours', 48);
  int get limit => config.paramInt('limit', 100);

  /// Radius (km) around the active reference point to scope the feed to.
  /// `<= 0` (or absent) fetches the global feed. Defaults to 2000 km so a
  /// user in India sees regional/South-Asia events, not European ones.
  double get regionRadiusKm => config.paramDouble('geoRadiusKm', 2000.0);

  static const _queryPath = '/fdsnws/event/1/query';

  @override
  Future<SourceFetchResult> fetch({
    DateTime? since,
    Coordinates? referencePoint,
  }) async {
    final now = DateTime.now().toUtc();
    final start = since?.toUtc() ?? now.subtract(Duration(hours: maxAgeHours));
    final params = {
      'format': 'geojson',
      'starttime': _iso(start),
      'endtime': _iso(now),
      'minmagnitude': '$minMagnitude',
      'orderby': 'time',
      'limit': '$limit',
    };
    final box = RegionScope.boxFor(referencePoint, regionRadiusKm);
    if (box != null) {
      // Official USGS query supports bounding-box filters.
      params['minlatitude'] = '${box.minLat}';
      params['maxlatitude'] = '${box.maxLat}';
      params['minlongitude'] = '${box.minLon}';
      params['maxlongitude'] = '${box.maxLon}';
    }
    final uri = Uri(
      scheme: 'https',
      host: Uri.parse(AppConfig.usgsBaseUrl).host,
      path: Uri.parse(AppConfig.usgsBaseUrl).path + _queryPath,
      queryParameters: params,
    );
    final http.Client client = _injectedClient ?? http.Client();
    try {
      final res = await client.get(uri).timeout(AppConfig.sourceTimeout);
      if (res.statusCode != 200) {
        throw SourceUnavailableException(
          id,
          'USGS responded with ${res.statusCode}',
        );
      }
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      return SourceFetchResult(
        sourceId: id,
        incidents: parse(decoded),
        fetchedAt: now,
      );
    } on SourceUnavailableException {
      rethrow;
    } on Object catch (e) {
      throw SourceUnavailableException(id, 'USGS request failed', e);
    } finally {
      if (_injectedClient == null) client.close();
    }
  }

  /// Public parser for tests. Maps the official GeoJSON `FeatureCollection`
  /// to [Disaster] entities.
  static List<Disaster> parse(Object? raw) {
    if (raw is! Map<String, dynamic>) return const [];
    final features = raw['features'];
    if (features is! List) return const [];
    final out = <Disaster>[];
    for (final f in features) {
      final d = tryParseFeature(f);
      if (d != null) out.add(d);
    }
    return out;
  }

  static Disaster? tryParseFeature(dynamic feature) {
    if (feature is! Map<String, dynamic>) return null;
    final props = feature['properties'];
    final geometry = feature['geometry'];
    if (props is! Map<String, dynamic> || geometry is! Map<String, dynamic>) {
      return null;
    }
    final id = feature['id']?.toString();
    final mag = (props['mag'] is num) ? (props['mag'] as num).toDouble() : null;
    final time = props['time'] is num ? (props['time'] as num).toInt() : null;
    final coords = geometry['coordinates'];
    if (id == null || coords is! List || coords.length < 2) return null;
    final lng = coords[0] is num ? (coords[0] as num).toDouble() : null;
    final lat = coords[1] is num ? (coords[1] as num).toDouble() : null;
    if (lat == null || lng == null) return null;

    final place = props['place']?.toString() ?? 'Earthquake';
    final title =
        props['title']?.toString() ??
        'M ${mag?.toStringAsFixed(1) ?? '?'} - $place';

    final severity = _severityFor(mag);
    try {
      final occurred = time == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(time);
      final hashInput = jsonEncode({
        'id': id,
        'mag': mag,
        'time': time,
        'place': place,
      });
      final d = Disaster(
        id: 'usgs_$id',
        type: DisasterType.earthquake,
        title: title,
        description:
            'Magnitude ${mag?.toStringAsFixed(1) ?? 'unknown'} '
            'earthquake reported by USGS at $place.',
        coordinates: Coordinates(lat, lng),
        affectedRadiusKm: _radiusKm(mag),
        severity: severity,
        magnitude: mag,
        status: DisasterStatus.active,
        occurredAt: occurred,
        createdAt: occurred,
        updatedAt: occurred ?? DateTime.now(),
        source: 'USGS',
        area: place,
        externalUrl: props['url']?.toString(),
        provider: DataProvider.server,
        payloadHash: sha256.convert(utf8.encode(hashInput)).toString(),
      );
      return d;
    } on ArgumentError {
      return null;
    }
  }

  static Severity _severityFor(double? mag) {
    if (mag == null) return Severity.minor;
    if (mag >= 7) return Severity.extreme;
    if (mag >= 6) return Severity.severe;
    if (mag >= 5) return Severity.moderate;
    return Severity.moderate;
  }

  static double _radiusKm(double? mag) {
    final m = mag ?? 5.0;
    return (m * 25.0).clamp(25.0, 250.0);
  }

  static String _iso(DateTime t) =>
      t.toUtc().toIso8601String().split('.').first;
}
