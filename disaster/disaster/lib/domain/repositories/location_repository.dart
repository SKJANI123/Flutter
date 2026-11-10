import 'package:disaster/domain/entities/location_record.dart';

/// Storage for saved user locations (the manual mode lets the app run
/// completely without GPS permission).
abstract class LocationRepository {
  Future<List<LocationRecord>> getAll();

  Future<LocationRecord?> getSelected();

  Future<void> upsert(LocationRecord location);

  Future<void> setSelected({
    required String locationId,
    required String mode,
  });

  /// Clears the selected flag (used when switching back to GPS mode, where no
  /// saved record is "selected" anymore).
  Future<void> clearSelected();

  Future<void> delete(String id);
}