import 'package:disaster/core/errors/exceptions.dart';
import 'package:disaster/domain/entities/disaster.dart';
import 'package:disaster/domain/enums/disaster_status.dart';
import 'package:disaster/domain/enums/disaster_type.dart';
import 'package:disaster/domain/enums/severity.dart';
import 'package:disaster/domain/value_objects/coordinates.dart';
import 'package:crypto/crypto.dart';

import 'dart:convert';

/// Parses raw payloads (from REST or WebSocket) into [Disaster] domain models.
///
/// Handles:
/// - `{'disaster': {...}}`  (WebSocket envelope)
/// - `{'events': [...]}`    (REST list envelope)
/// - Nested `data` keys, int/double coercions, missing optional fields
/// - malformed payloads -> returned as `null` entry / throws [ParseException]
class DisasterEventParser {
  DisasterEventParser._();

  static String hashPayload(dynamic raw) {
    final json = raw is String ? raw : jsonEncode(raw);
    return sha256.convert(utf8.encode(json)).toString();
  }

  /// Parses a single disaster payload. Returns null when the payload isn't a
  /// disaster event (e.g. a heartbeat or acknowledgement frame).
  static Disaster? tryParseSingle(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;

    var data = _unwrapEnvelope(raw);
    if (data == null) return null;

    final id = data['id'] ?? data['event_id'] ?? data['uuid'];
    if (id == null || id.toString().isEmpty) return null;

    final type = DisasterType.fromCode(
      _asString(data['type'] ?? data['disaster_type'] ?? data['category']),
    );
    if (type == null) return null;

    final lat = _asDouble(data['latitude'] ?? data['lat']);
    final lng = _asDouble(data['longitude'] ?? data['lng'] ?? data['lon']);
    if (lat == null || lng == null) return null;

    try {
      return Disaster(
        id: id.toString(),
        type: type,
        title:
            _asString(data['title'] ?? data['name'] ?? _defaultTitle(type)) ??
            _defaultTitle(type),
        description: _asString(data['description'] ?? data['details']),
        coordinates: Coordinates(lat, lng),
        affectedRadiusKm:
            _asDouble(
              data['affected_radius_km'] ?? data['radius_km'] ?? data['radius'],
            ) ??
            10,
        severity:
            Severity.fromCode(_asString(data['severity'])) ?? Severity.info,
        magnitude: _asDouble(data['magnitude'] ?? data['mag']),
        status: DisasterStatus.fromCode(_asString(data['status'])),
        occurredAt: _asDateTime(
          data['occurred_at'] ?? data['time'] ?? data['started_at'],
        ),
        expiresAt: _asDateTime(data['expires_at'] ?? data['expiry']),
        createdAt: _asDateTime(data['created_at']),
        updatedAt: _asDateTime(data['updated_at']) ?? DateTime.now(),
        source: _asString(data['source'] ?? data['agency']),
        provider: DataProvider.server,
        payloadHash: hashPayload(data),
      );
    } catch (_) {
      return null;
    }
  }

  static List<Disaster> tryParseList(dynamic raw) {
    if (raw is! Map<String, dynamic>) return const [];
    final events = raw['events'] ?? raw['data'] ?? raw['disasters'];
    if (events is! List) return const [];
    return events.map((e) => tryParseSingle(e)).whereType<Disaster>().toList();
  }

  static Disaster parseSingle(dynamic raw) {
    final d = tryParseSingle(raw);
    if (d == null) {
      throw const ParseException('Malformed disaster payload');
    }
    return d;
  }

  /// WebSocket envelopes may be `{"type":"disaster","data":{...}}` or a plain
  /// disaster object. Resolves to the payload map or null.
  static Map<String, dynamic>? _unwrapEnvelope(Map<String, dynamic> raw) {
    if (raw.containsKey('disaster') &&
        raw['disaster'] is Map<String, dynamic>) {
      return raw['disaster'] as Map<String, dynamic>;
    }
    final data = raw['data'];
    if (data is Map<String, dynamic>) return data;
    // Already the disaster object itself.
    if (raw.containsKey('id') &&
        (raw.containsKey('type') || raw.containsKey('latitude'))) {
      return raw;
    }
    return null;
  }

  static String _defaultTitle(DisasterType t) {
    final labels = {
      'earthquake': 'Earthquake',
      'flood': 'Flood',
      'cyclone': 'Cyclone',
      'tsunami': 'Tsunami',
      'landslide': 'Landslide',
      'wildfire': 'Wildfire',
      'heavy_rain': 'Heavy Rain',
      'lightning': 'Lightning',
      'storm': 'Storm',
      'extreme_heat': 'Extreme Heat',
      'volcano': 'Volcano',
    };
    return labels[t.code] ?? t.code;
  }

  static String? _asString(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static double? _asDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static DateTime? _asDateTime(dynamic v) {
    if (v == null) return null;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is String) {
      final parsed = DateTime.tryParse(v);
      if (parsed != null) return parsed.toLocal();
    }
    return null;
  }
}
