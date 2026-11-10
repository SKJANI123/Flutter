import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:disaster/core/errors/exceptions.dart';
import 'package:disaster/domain/entities/emergency_contact.dart';
import 'package:disaster/domain/entities/sos_event.dart';
import 'package:disaster/presentation/providers/app_dependencies.dart';
import 'package:disaster/presentation/providers/location_controller.dart';

class SosController extends ChangeNotifier {
  SosController({required this._deps, required LocationController location}) {
    _deps.sos.events.listen((e) {
      _history = _history..insert(0, e);
      notifyListeners();
    });
    _loadHistory();
  }

  final AppDependencies _deps;

  List<SosEvent> _history = [];
  List<SosEvent> get history => _history;

  bool _dispatching = false;
  bool get dispatching => _dispatching;
  Object? _lastError;
  Object? get lastError => _lastError;

  List<EmergencyContact> _selectedContacts = [];
  List<EmergencyContact> get selectedContacts => _selectedContacts;
  bool get hasSelection => _selectedContacts.isNotEmpty;

  Future<List<EmergencyContact>> loadContacts() => _deps.contacts.getAll();

  void selectContact(EmergencyContact contact, bool selected) {
    if (selected) {
      if (!_selectedContacts.any((c) => c.id == contact.id)) {
        _selectedContacts = [..._selectedContacts, contact];
      }
    } else {
      _selectedContacts = _selectedContacts
          .where((c) => c.id != contact.id)
          .toList();
    }
    notifyListeners();
  }

  /// Sends the SOS using the GPS fix and chosen contacts.
  Future<SosEvent?> dispatch({String? message}) async {
    _dispatching = true;
    _lastError = null;
    notifyListeners();
    try {
      final recipients = _selectedContacts.isEmpty ? null : _selectedContacts;
      final event = await _deps.sos.trigger(
        message: message ?? _defaultMessage(),
        recipients: recipients,
      );
      _dispatching = false;
      notifyListeners();
      if (event != null) {
        // Fallback: share location via SMS with each selected contact.
        for (final c in _selectedContacts) {
          await _deps.sos.shareLocationWithContact(
            c,
            lat: event.latitude,
            lng: event.longitude,
            message: event.message ?? 'Emergency! My location:',
          );
        }
      }
      return event;
    } on SosException catch (e) {
      _lastError = e;
      _dispatching = false;
      notifyListeners();
      return null;
    } catch (e) {
      _lastError = e;
      _dispatching = false;
      notifyListeners();
      return null;
    }
  }

  Future<void> _loadHistory() async {
    try {
      _history = await _deps.sos.history();
    } catch (_) {
      _history = [];
    }
    notifyListeners();
  }

  Future<void> retrySync(String id) async {
    await _deps.sos.retrySync(id);
    await _loadHistory();
  }

  String _defaultMessage() =>
      'EMERGENCY — I need help. My live location is shared with you.';
}
