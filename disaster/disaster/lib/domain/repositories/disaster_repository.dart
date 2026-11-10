import 'package:disaster/domain/entities/disaster.dart';
import 'package:disaster/domain/enums/disaster_type.dart';

abstract class DisasterRepository {
  /// Persists a single disaster (upsert by id).
  Future<void> upsert(Disaster disaster);

  /// Marks returned disaster ids as resolved/expired.
  Future<void> upsertAll(List<Disaster> disasters);

  Future<Disaster?> findById(String id);

  Future<List<Disaster>> findAll({
    List<DisasterType>? types,
    bool onlyActive = true,
    int? limit,
    int offset = 0,
  });

  Future<List<Disaster>> findByProvider(
    String provider, {
    bool onlyActive = true,
  });

  Future<List<Disaster>> findAllActive();

  Future<int> count();

  Future<void> deleteById(String id);

  Future<void> deleteOlderThan(DateTime before);

  Future<void> clearSimulatorData();

  Future<void> close();
}
