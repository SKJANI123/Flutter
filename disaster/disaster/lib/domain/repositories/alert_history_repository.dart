import 'package:disaster/domain/entities/alert_history_entry.dart';
import 'package:disaster/domain/enums/alert_level.dart';
import 'package:disaster/domain/enums/disaster_type.dart';

abstract class AlertHistoryRepository {
  Future<void> insert(AlertHistoryEntry entry);
  Future<AlertHistoryEntry?> latestForDisaster(String disasterId);
  Future<List<AlertHistoryEntry>> getAll({int limit = 200});
  Future<List<AlertHistoryEntry>> search({
    String? query,
    List<DisasterType>? types,
    AlertLevel? minLevel,
  });
  Future<void> updateNotificationStatus(String id, {required String status});
  Future<void> deleteOlderThan(DateTime before);
}
