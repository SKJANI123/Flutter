import 'package:disaster/domain/value_objects/coordinates.dart';

enum SafePlaceType {
  shelter('shelter'),
  hospital('hospital'),
  policeStation('police_station'),
  reliefCamp('relief_camp'),
  safeZone('safe_zone');

  const SafePlaceType(this.code);
  final String code;

  static SafePlaceType fromCode(String? code) {
    for (final t in SafePlaceType.values) {
      if (t.code == code?.toLowerCase()) return t;
    }
    return SafePlaceType.shelter;
  }
}

class Shelter {
  const Shelter({
    required this.id,
    required this.name,
    required this.coordinates,
    this.address,
    this.phone,
    this.type = SafePlaceType.shelter,
    this.capacity,
    this.isOpen = true,
    this.source = 'server',
    this.distanceKm,
  });

  final String id;
  final String name;
  final String? address;
  final Coordinates coordinates;
  final String? phone;
  final SafePlaceType type;
  final int? capacity;
  final bool isOpen;
  final String source;

  /// Distance in km from the user (filled in by the shelters controller).
  final double? distanceKm;

  Shelter withDistanceKm(double? distance) {
    return Shelter(
      id: id,
      name: name,
      address: address,
      coordinates: coordinates,
      phone: phone,
      type: type,
      capacity: capacity,
      isOpen: isOpen,
      source: source,
      distanceKm: distance,
    );
  }
}
