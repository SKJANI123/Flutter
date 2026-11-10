import 'package:disaster/domain/enums/alert_level.dart';
import 'package:disaster/domain/entities/disaster.dart';

enum NotificationStatus {
  none('none'),
  scheduled('scheduled'),
  sent('sent'),
  failed('failed'),
  suppressed('suppressed');

  const NotificationStatus(this.code);
  final String code;

  static NotificationStatus fromCode(String? code) {
    for (final s in NotificationStatus.values) {
      if (s.code == code?.toLowerCase()) return s;
    }
    return NotificationStatus.none;
  }
}

/// One row of the alert history: a snapshot of the user's assessed level for a
/// disaster at a point in time.
class AlertHistoryEntry {
  const AlertHistoryEntry({
    required this.id,
    required this.disasterId,
    this.distanceKm,
    this.previousLevel,
    required this.newLevel,
    this.triggeredAt,
    this.notificationStatus = NotificationStatus.none,
    this.disaster,
  });

  final String id;
  final String disasterId;
  final double? distanceKm;
  final AlertLevel? previousLevel;
  final AlertLevel newLevel;
  final DateTime? triggeredAt;
  final NotificationStatus notificationStatus;

  /// Joined disaster (when available) for display purposes.
  final Disaster? disaster;

  AlertHistoryEntry copyWith({NotificationStatus? notificationStatus}) {
    return AlertHistoryEntry(
      id: id,
      disasterId: disasterId,
      distanceKm: distanceKm,
      previousLevel: previousLevel,
      newLevel: newLevel,
      triggeredAt: triggeredAt,
      notificationStatus: notificationStatus ?? this.notificationStatus,
      disaster: disaster,
    );
  }
}
