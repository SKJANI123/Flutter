import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import 'package:disaster/core/config/app_config.dart';
import 'package:disaster/data/sources/disaster_source.dart';
import 'package:disaster/data/sources/region_scope.dart';
import 'package:disaster/data/sources/source_config.dart';
import 'package:disaster/domain/entities/disaster.dart';
import 'package:disaster/domain/enums/disaster_status.dart';
import 'package:disaster/domain/enums/disaster_type.dart';
import 'package:disaster/domain/enums/severity.dart';
import 'package:disaster/domain/value_objects/coordinates.dart';

/// Official UN GDACS (Global Disaster Alert & Coordination System) feed —
/// floods, cyclones, tsunamis, wildfires and volcanoes with humanitarian
/// impact. Public-domain GeoRSS, no key required.
///
/// Endpoint overridable via `--dart-define=GDACS_BASE_URL=...`.
class GdacsSource implements DisasterSource {
  GdacsSource({required this.config, http.Client? client})
    : _injectedClient = client;

  final SourceConfigEntry config;
  final http.Client? _injectedClient;

  @override
  String get id => config.id;

  @override
  String get name => config.name;

  @override
  String get description => config.description;

  int get maxAgeDays => config.paramInt('maxAgeDays', 30);

  /// Radius (km) around the active reference point to keep incidents within.
  /// `<= 0` (or absent) keeps the whole global feed. Defaults to 2000 km so a
  /// user in India sees regional/South-Asia events, not European ones.
  double get regionRadiusKm => config.paramDouble('geoRadiusKm', 2000.0);

  @override
  Future<SourceFetchResult> fetch({
    DateTime? since,
    Coordinates? referencePoint,
  }) async {
    final uri = Uri.parse('${AppConfig.gdacsBaseUrl}/xml/rss.xml');
    final http.Client client = _injectedClient ?? http.Client();
    try {
      final res = await client.get(uri).timeout(AppConfig.sourceTimeout);
      if (res.statusCode != 200) {
        throw SourceUnavailableException(
          id,
          'GDACS responded with ${res.statusCode}',
        );
      }
      final text = utf8.decode(res.bodyBytes);
      // The RSS endpoint has no server-side bounding box, so the parsed feed
      // is narrowed client-side to the region around the active location.
      final incidents = referencePoint == null || regionRadiusKm <= 0
          ? parse(text)
          : parse(text)
                .where(
                  (d) =>
                      RegionScope.insideRadius(
                        referencePoint,
                        d.coordinates,
                        regionRadiusKm,
                      ),
                )
                .toList();
      return SourceFetchResult(
        sourceId: id,
        incidents: incidents,
        fetchedAt: DateTime.now().toUtc(),
      );
    } on SourceUnavailableException {
      rethrow;
    } on Object catch (e) {
      throw SourceUnavailableException(id, 'GDACS request failed', e);
    } finally {
      if (_injectedClient == null) client.close();
    }
  }

  /// Public parser for tests. Maps the official GeoRSS `<item>`s to
  /// [Disaster] entities, skipping unsupported event types.
  static List<Disaster> parse(String xml) {
    final out = <Disaster>[];
    XmlDocument doc;
    try {
      doc = XmlDocument.parse(xml);
    } on XmlException {
      return const [];
    }
    for (final item in doc.findAllElements('item')) {
      final d = tryParseItem(item);
      if (d != null) out.add(d);
    }
    return out;
  }

  static Disaster? tryParseItem(XmlElement item) {
    // GDACS RSS declares `gdacs:` and `geo:` namespaces; field access must
    // match the qualified names, falling back to plain names for safety.
    String? text(String local) {
      for (final qualified in ['gdacs:$local', 'geo:$local', local]) {
        for (final e in item.findAllElements(qualified)) {
          return e.innerText.trim();
        }
      }
      return null;
    }

    final typeCode = (text('eventtype') ?? '').toUpperCase();
    final type = _typeFor(typeCode);
    if (type == null) return null;

    final isCurrent = (text('iscurrent') ?? 'true').toLowerCase() == 'true';
    final alertLevel = (text('alertlevel') ?? 'green').toLowerCase();
    final guid = text('guid');
    if (guid == null) return null;

    final lat = double.tryParse(text('lat') ?? '');
    final lng = double.tryParse(text('long') ?? '');
    if (lat == null || lng == null) return null;

    var title = text('title') ?? '$alertLevel ${type.label} alert';
    var area = text('area') ?? _extractArea(title);
    title = _titleFor(alertLevel, type, area, fallback: title);

    final from = _parseDate(text('fromdate'));
    final to = _parseDate(text('todate'));

    try {
      final hashInput = jsonEncode({
        'guid': guid,
        'type': typeCode,
        'title': title,
        'level': alertLevel,
      });
      final d = Disaster(
        id: 'gdacs_$guid',
        type: type,
        title: title,
        description: text('description') ?? 'No description provided.',
        coordinates: Coordinates(lat, lng),
        affectedRadiusKm: _radiusKm(item),
        severity: _severityFor(alertLevel, typeCode),
        status: isCurrent ? DisasterStatus.active : DisasterStatus.resolved,
        occurredAt: from,
        expiresAt: to,
        createdAt: _parseDate(text('dateadded')) ?? from,
        updatedAt: _parseDate(text('datemodified')) ?? from,
        source: 'GDACS',
        area: area,
        externalUrl: text('link'),
        provider: DataProvider.server,
        payloadHash: sha256.convert(utf8.encode(hashInput)).toString(),
      );
      return d;
    } on ArgumentError {
      return null;
    }
  }

  static DisasterType? _typeFor(String code) => switch (code) {
    'EQ' => DisasterType.earthquake,
    'TC' => DisasterType.cyclone,
    'FL' => DisasterType.flood,
    'TS' => DisasterType.tsunami,
    'WF' => DisasterType.wildfire,
    'VO' => DisasterType.volcano,
    _ => null,
  };

  static Severity _severityFor(String alertLevel, String typeCode) {
    // Alert-score (dc:subject suffix) refines severity when present.
    switch (alertLevel) {
      case 'red':
        return Severity.extreme;
      case 'orange':
        return Severity.severe;
      case 'green':
        return Severity.moderate;
      default:
        return Severity.minor;
    }
  }

  static String _titleFor(
    String alertLevel,
    DisasterType type,
    String area, {
    required String fallback,
  }) {
    final label = switch (alertLevel) {
      'red' => 'Severe',
      'orange' => 'Moderate',
      _ => 'Green',
    };
    final base = label == 'Green'
        ? '${type.label} Alert'
        : '$label ${type.label} Warning';
    return area.isEmpty ? base : '$base — $area';
  }

  /// "Red flood alert in Thailand" -> "Thailand".
  static String _extractArea(String title) {
    final match = RegExp(
      r'^(?:[Rr]ed|[Oo]range|[Gg]reen|[Ww]hite)\s+.*?\s+alert\s+in\s+(.+)$',
    ).firstMatch(title.trim());
    final raw = match?.group(1);
    if (raw == null) return '';
    return raw.replaceAll(RegExp(r'\s+\(.*\)$'), '').trim();
  }

  /// Approximates the affected radius from the official `<gdacs:bbox>` (km).
  static double _radiusKm(XmlElement item) {
    String? bbox;
    for (final name in ['gdacs:bbox', 'bbox']) {
      for (final e in item.findAllElements(name)) {
        bbox = e.innerText.trim();
      }
    }
    if (bbox == null) return 100.0;
    final parts = bbox
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.length < 4) return 100.0;
    final lonMin = double.tryParse(parts[0]);
    final lonMax = double.tryParse(parts[1]);
    final latMin = double.tryParse(parts[2]);
    final latMax = double.tryParse(parts[3]);
    if (lonMin == null || lonMax == null || latMin == null || latMax == null) {
      return 100.0;
    }
    final cLat = (latMin + latMax) / 2;
    final dLat = (latMax - latMin) / 2;
    final dLon = (lonMax - lonMin) / 2;
    final r1 = _approxKm(cLat, cLat + dLat, lonMin, lonMin);
    final r2 = _approxKm(cLat, cLat, lonMin, lonMin + dLon);
    return (math.max(r1, r2) * 0.62).clamp(25.0, 600.0);
  }

  static double _approxKm(double lat1, double lat2, double lon1, double lon2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static DateTime? _parseDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return HttpDate.parse(raw).toLocal();
    } on FormatException {
      return DateTime.tryParse(raw);
    }
  }
}
