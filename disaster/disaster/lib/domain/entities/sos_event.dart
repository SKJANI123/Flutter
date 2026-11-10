import 'package:disaster/domain/value_objects/coordinates.dart';

enum SosStatus {
  pending('pending'),
  queued('queued'),
  sent('sent'),
  delivered('delivered'),
  failed('failed');

  const SosStatus(this.code);
  final String code;

  static SosStatus fromCode(String? code) {
    for (final s in SosStatus.values) {
      if (s.code == code?.toLowerCase()) return s;
    }
    return SosStatus.pending;
  }
}

enum SosChannel {
  sms('sms'),
  call('call'),
  whatsapp('whatsapp'),
  location('location');

  const SosChannel(this.code);
  final String code;

  static SosChannel fromCode(String? code) {
    for (final c in SosChannel.values) {
      if (c.code == code?.toLowerCase()) return SosChannel.sms;
    }
    return SosChannel.sms;
  }
}

/// A confirmed emergency / SOS event raised by the user.
class SosEvent {
  const SosEvent({
    required this.id,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.status = SosStatus.pending,
    this.channels = const [SosChannel.sms, SosChannel.location],
    this.contactIds = const [],
    this.message,
    this.capturedAt,
    this.updatedAt,
  });

  final String id;
  final double latitude;
  final double longitude;
  final double? accuracy;
  final SosStatus status;
  final List<SosChannel> channels;
  final List<String> contactIds;
  final String? message;
  final DateTime? capturedAt;
  final DateTime? updatedAt;

  Coordinates get coordinates => Coordinates(latitude, longitude);

  bool get needsSync =>
      status == SosStatus.queued || status == SosStatus.pending;

  SosEvent copyWith({
    SosStatus? status,
    SosChannel? appendedChannel,
    DateTime? updatedAt,
  }) {
    return SosEvent(
      id: id,
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      status: status ?? this.status,
      channels: appendedChannel != null
          ? [...channels, appendedChannel]
          : channels,
      contactIds: contactIds,
      message: message,
      capturedAt: capturedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
