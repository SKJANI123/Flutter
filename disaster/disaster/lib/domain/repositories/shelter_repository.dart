import 'package:disaster/domain/entities/shelter.dart';

abstract class ShelterRepository {
  Future<void> upsertAll(List<Shelter> shelters);
  Future<void> upsert(Shelter shelter);
  Future<List<Shelter>> getAll();
  Future<Shelter?> getById(String id);
  Future<void> deleteById(String id);
}
