import 'package:disaster/domain/enums/alert_level.dart';
import 'package:disaster/domain/enums/disaster_status.dart';
import 'package:disaster/domain/enums/disaster_type.dart';
import 'package:disaster/domain/enums/severity.dart';
import 'package:disaster/domain/value_objects/coordinates.dart';

/// A disaster alert event. This is the canonical domain model used everywhere
/// in the app (REST, WebSocket and simulator all produce this shape).
class Disaster {
  const Disaster({
    required this.id,
    required this.type,
    required this.title,
    required this.coordinates,
    required this.affectedRadiusKm,
    required this.severity,
    this.description,
    this.magnitude,
    this.status = DisasterStatus.active,
    this.occurredAt,
    this.expiresAt,
    this.createdAt,
    this.updatedAt,
    this.source,
    this.provider = DataProvider.server,
    this.payloadHash,
    this.instructions,
    this.area,
    this.externalUrl,
  });

  final String id;
  final DisasterType type;
  final String title;
  final String? description;
  final Coordinates coordinates;
  final double affectedRadiusKm;
  final Severity severity;
  final double? magnitude;
  final DisasterStatus status;
  final DateTime? occurredAt;
  final DateTime? expiresAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? source;

  /// Distinguishes production (server) data from the dev simulator.
  final DataProvider provider;

  /// Fingerprint of the raw payload used for de-duplication.
  final String? payloadHash;

  /// Safety instructions issued by the source authority (e.g. CAP
  /// `<instruction>`); shown verbatim on the detail screen.
  final String? instructions;

  /// Human-readable area/region name affected by the event.
  final String? area;

  /// Link to the official source report for this incident.
  final String? externalUrl;

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  bool get isActive => status == DisasterStatus.active && !isExpired;

  /// Severity-related multiplier used when computing the alert level.
  double get severityBoost => (severity.weight - 1) * 0.15;

  /// Threshold for [AlertLevel.critical] expressed as a fraction of the
  /// affected radius.
  static const double criticalFraction = 0.25;

  /// Threshold for [AlertLevel.danger].
  static const double dangerFraction = 0.5;

  /// Threshold for [AlertLevel.warning].
  static const double warningFraction = 1.0;

  /// Computes the user [AlertLevel] for a given distance in km.
  ///
  /// The intrinsic severity of the event nudges the level up so that a Severe
  /// or Extreme event is rated more carefully than a Minor one at the same
  /// distance.
  AlertLevel levelForDistance(double distanceKm) {
    var weight = 0;
    final ratio = affectedRadiusKm <= 0 ? 0.0 : distanceKm / affectedRadiusKm;

    if (ratio <= criticalFraction) {
      weight = AlertLevel.critical.weight;
    } else if (ratio <= dangerFraction) {
      weight = AlertLevel.danger.weight;
    } else if (ratio <= warningFraction) {
      weight = AlertLevel.warning.weight;
    }

    // Escalate based on intrinsic severity (severe/extreme).
    final boost = (severity.weight - Severity.moderate.weight).clamp(0, 2);
    weight = (weight + boost).clamp(0, AlertLevel.critical.weight);

    return AlertLevel.values.firstWhere((l) => l.weight == weight);
  }

  Disaster copyWith({
    String? id,
    DisasterType? type,
    String? title,
    String? description,
    Coordinates? coordinates,
    double? affectedRadiusKm,
    Severity? severity,
    double? magnitude,
    DisasterStatus? status,
    DateTime? occurredAt,
    DateTime? expiresAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? source,
    DataProvider? provider,
    String? payloadHash,
    String? instructions,
    String? area,
    String? externalUrl,
  }) {
    return Disaster(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      coordinates: coordinates ?? this.coordinates,
      affectedRadiusKm: affectedRadiusKm ?? this.affectedRadiusKm,
      severity: severity ?? this.severity,
      magnitude: magnitude ?? this.magnitude,
      status: status ?? this.status,
      occurredAt: occurredAt ?? this.occurredAt,
      expiresAt: expiresAt ?? this.expiresAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      source: source ?? this.source,
      provider: provider ?? this.provider,
      payloadHash: payloadHash ?? this.payloadHash,
      instructions: instructions ?? this.instructions,
      area: area ?? this.area,
      externalUrl: externalUrl ?? this.externalUrl,
    );
  }
}
