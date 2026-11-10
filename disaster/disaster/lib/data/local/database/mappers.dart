import 'package:disaster/domain/entities/disaster.dart';
import 'package:disaster/domain/enums/disaster_status.dart';
import 'package:disaster/domain/enums/disaster_type.dart';
import 'package:disaster/domain/enums/severity.dart';
import 'package:disaster/domain/value_objects/coordinates.dart';

/// Row <-> entity mappings shared across the local data layer.
class DisasterMappers {
  DisasterMappers._();

  static Map<String, dynamic> toRow(Disaster d) => {
    'id': d.id,
    'type': d.type.code,
    'title': d.title,
    'description': d.description,
    'latitude': d.coordinates.latitude,
    'longitude': d.coordinates.longitude,
    'affected_radius_km': d.affectedRadiusKm,
    'severity': d.severity.code,
    'magnitude': d.magnitude,
    'status': d.status.code,
    'occurred_at': d.occurredAt?.millisecondsSinceEpoch,
    'expires_at': d.expiresAt?.millisecondsSinceEpoch,
    'created_at': d.createdAt?.millisecondsSinceEpoch,
    'updated_at': d.updatedAt?.millisecondsSinceEpoch,
    'source': d.source,
    'provider': d.provider.value,
    'payload_hash': d.payloadHash,
    'instructions': d.instructions,
    'area': d.area,
    'external_url': d.externalUrl,
  };

  static Disaster fromRow(Map<String, dynamic> row) => Disaster(
    id: row['id'] as String,
    type: DisasterType.fromCode(row['type'] as String?) ?? DisasterType.storm,
    title: row['title'] as String,
    description: row['description'] as String?,
    coordinates: Coordinates(_num(row, 'latitude'), _num(row, 'longitude')),
    affectedRadiusKm: _num(row, 'affected_radius_km'),
    severity: Severity.fromCode(row['severity'] as String?) ?? Severity.info,
    magnitude: (row['magnitude'] as num?)?.toDouble(),
    status: DisasterStatus.fromCode(row['status'] as String?),
    occurredAt: _fromEpoch(row['occurred_at']),
    expiresAt: _fromEpoch(row['expires_at']),
    createdAt: _fromEpoch(row['created_at']),
    updatedAt: _fromEpoch(row['updated_at']),
    source: row['source'] as String?,
    provider: DataProvider.fromValue(row['provider'] as String?),
    payloadHash: row['payload_hash'] as String?,
    instructions: row['instructions'] as String?,
    area: row['area'] as String?,
    externalUrl: row['external_url'] as String?,
  );

  static double _num(Map<String, dynamic> row, String key) =>
      (row[key] as num?)?.toDouble() ?? 0;

  static DateTime? _fromEpoch(Object? v) =>
      v is int ? DateTime.fromMillisecondsSinceEpoch(v) : null;
}
