import 'package:flutter/foundation.dart';

import 'package:disaster/domain/entities/emergency_contact.dart';
import 'package:disaster/presentation/providers/app_dependencies.dart';
import 'package:uuid/uuid.dart';

class ContactsController extends ChangeNotifier {
  ContactsController({required this._deps}) {
    load();
  }

  final AppDependencies _deps;

  List<EmergencyContact> _contacts = [];
  List<EmergencyContact> get contacts => _contacts;
  bool _loading = true;
  bool get loading => _loading;
  Object? _error;
  Object? get error => _error;

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    try {
      _contacts = await _deps.contacts.getAll();
      _error = null;
    } on Object catch (e) {
      _error = e;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> add({
    required String name,
    required String phone,
    String? relationship,
    bool isPrimary = false,
  }) async {
    final contact = EmergencyContact(
      id: const Uuid().v4(),
      name: name.trim(),
      phone: phone.trim(),
      relationship: relationship?.trim(),
      isPrimary: isPrimary,
      createdAt: DateTime.now(),
    );
    await _deps.contacts.insert(contact);
    await load();
  }

  Future<void> update(EmergencyContact contact) async {
    await _deps.contacts.update(contact);
    await load();
  }

  Future<void> setPrimary(EmergencyContact contact) async {
    await update(contact.copyWith(isPrimary: true));
  }

  Future<void> remove(String id) async {
    await _deps.contacts.deleteById(id);
    await load();
  }
}
