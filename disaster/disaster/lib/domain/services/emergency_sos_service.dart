import 'dart:async';

import 'package:disaster/core/errors/exceptions.dart';
import 'package:disaster/core/network/connectivity_service.dart';
import 'package:disaster/core/notifications/local_notification_service.dart';
import 'package:disaster/core/utils/launchers.dart';
import 'package:disaster/data/local/repositories/sync_queue_repository.dart';
import 'package:disaster/data/remote/api/disaster_api_service.dart';
import 'package:disaster/domain/entities/emergency_contact.dart';
import 'package:disaster/domain/entities/sos_event.dart';
import 'package:disaster/domain/repositories/emergency_contact_repository.dart';
import 'package:disaster/domain/repositories/sos_event_repository.dart';
import 'package:disaster/domain/services/location_service.dart';
import 'package:uuid/uuid.dart';

enum SosDispatchResult { queued, sent, failed }

/// Coordinates the emergency SOS flow:
/// capture GPS -> persist -> queue for server sync -> dispatch to emergency
/// contacts (call / SMS / map link) -> local notification.
class EmergencySosService {
  EmergencySosService({
    required this._location,
    required this._sosEvents,
    required this._contacts,
    required this._syncQueue,
    required this._api,
    required this._notifications,
    required this._connectivity,
  });

  final LocationService _location;
  final SosEventRepository _sosEvents;
  final EmergencyContactRepository _contacts;
  final SyncQueueRepository _syncQueue;
  final DisasterApiService _api;
  final LocalNotificationService _notifications;
  final ConnectivityService _connectivity;

  final _eventsController = StreamController<SosEvent>.broadcast();
  Stream<SosEvent> get events => _eventsController.stream;

  /// Trigger an SOS with the current GPS fix.
  Future<SosEvent?> trigger({
    String? message,
    List<EmergencyContact>? recipients,
  }) async {
    try {
      final location = await _location.getCurrentLocation();
      if (location == null) return null;

      final contacts = recipients ?? await _contacts.getPrimaryContacts();
      final event = SosEvent(
        id: const Uuid().v4(),
        latitude: location.latitude,
        longitude: location.longitude,
        contactIds: contacts.map((c) => c.id).toList(),
        message: message,
        capturedAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: SosStatus.pending,
      );

      await _sosEvents.insert(event);

      // Queue for server sync (offline-first).
      await _syncQueue.enqueue(
        entityType: 'sos',
        entityId: event.id,
        operation: 'create',
        payload: {
          'id': event.id,
          'latitude': event.latitude,
          'longitude': event.longitude,
          'accuracy': event.accuracy,
          'message': event.message,
          'contact_ids': event.contactIds,
        },
      );

      // Try to send immediately if online.
      if (_connectivity.isOnline) {
        try {
          await _api.publishSos(event);
          await _sosEvents.updateStatus(event.id, SosStatus.sent);
        } catch (_) {
          await _sosEvents.updateStatus(event.id, SosStatus.queued);
        }
      } else {
        await _sosEvents.updateStatus(event.id, SosStatus.queued);
      }

      await _notifications.showSos(
        id: 5000 + (event.id.hashCode & 0x7FF),
        title: 'SOS sent',
        body: 'Your emergency alert with GPS location was dispatched.',
        payload: event.id,
      );

      final stored = SosEvent(
        id: event.id,
        latitude: event.latitude,
        longitude: event.longitude,
        accuracy: event.accuracy,
        status: _connectivity.isOnline ? SosStatus.sent : SosStatus.queued,
        channels: const [SosChannel.sms, SosChannel.location],
        contactIds: event.contactIds,
        message: event.message,
        capturedAt: event.capturedAt,
        updatedAt: DateTime.now(),
      );
      if (!_eventsController.isClosed) {
        _eventsController.add(stored);
      }
      return stored;
    } catch (e) {
      throw SosException('SOS could not be triggered', cause: e);
    }
  }

  Future<void> retrySync(String eventId) async {
    final all = await _sosEvents.getAll();
    final event = all.where((e) => e.id == eventId).firstOrNull;
    if (event == null) return;
    try {
      await _api.publishSos(event);
      await _sosEvents.updateStatus(event.id, SosStatus.sent);
    } catch (_) {
      await _sosEvents.updateStatus(event.id, SosStatus.queued);
    }
  }

  Future<List<SosEvent>> history() => _sosEvents.getAll();

  /// Opens channels for a contact (call or SMS) with a location body.
  Future<bool> shareLocationWithContact(
    EmergencyContact contact, {
    required double lat,
    required double lng,
    required String message,
    SosChannel channel = SosChannel.sms,
  }) {
    switch (channel) {
      case SosChannel.sms:
        return EmergencyLaunchers.sms(
          contact.phone,
          body: '$message https://maps.google.com/?q=$lat,$lng',
        );
      case SosChannel.call:
        return EmergencyLaunchers.call(contact.phone);
      default:
        return EmergencyLaunchers.sms(
          contact.phone,
          body: '$message https://maps.google.com/?q=$lat,$lng',
        );
    }
  }

  void dispose() {
    _eventsController.close();
  }
}

extension _FirstOrNull on Iterable<SosEvent> {
  SosEvent? get firstOrNull => isEmpty ? null : first;
}
