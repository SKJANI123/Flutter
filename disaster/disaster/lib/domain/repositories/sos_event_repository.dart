import 'package:disaster/domain/entities/sos_event.dart';

abstract class SosEventRepository {
  Future<void> insert(SosEvent event);
  Future<List<SosEvent>> getAll({bool newestFirst = true});
  Future<List<SosEvent>> getNeedingSync();
  Future<void> updateStatus(String id, SosStatus status);
  Future<void> deleteById(String id);
}
