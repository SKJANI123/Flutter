import 'package:disaster/domain/entities/emergency_contact.dart';

abstract class EmergencyContactRepository {
  Future<List<EmergencyContact>> getAll();
  Future<EmergencyContact?> getById(String id);
  Future<void> insert(EmergencyContact contact);
  Future<void> update(EmergencyContact contact);
  Future<void> deleteById(String id);
  Future<List<EmergencyContact>> getPrimaryContacts();
}
