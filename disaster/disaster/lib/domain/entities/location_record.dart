import 'package:disaster/domain/value_objects/coordinates.dart';

/// How a location was obtained.
enum LocationMode {
  /// Live GPS fix.
  gps('gps'),

  /// Manually entered / geocoded place (city, district, state, PIN, address).
  manual('manual');

  const LocationMode(this.code);
  final String code;

  static LocationMode fromCode(String? code) {
    for (final m in LocationMode.values) {
      if (m.code == code) return m;
    }
    return LocationMode.gps;
  }
}

/// A place the user has chosen (manually) or is currently using (GPS). Pins
/// the alert proximity calculations to a fixed point and lets the app work
/// with no GPS permission at all.
class LocationRecord {
  const LocationRecord({
    required this.id,
    required this.coordinates,
    this.mode = LocationMode.manual,
    this.label,
    this.city,
    this.district,
    this.state,
    this.pinCode,
    this.address,
    this.isSelected = false,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final Coordinates coordinates;
  final LocationMode mode;
  final String? label;
  final String? city;
  final String? district;
  final String? state;
  final String? pinCode;
  final String? address;
  final bool isSelected;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Human-readable summary ("Surat, Gujarat · 395001").
  String get summary {
    final parts = <String>[
      if (label != null && label!.trim().isNotEmpty) label!.trim(),
      if (state != null && state!.trim().isNotEmpty) state!.trim(),
      if (pinCode != null && pinCode!.trim().isNotEmpty) pinCode!.trim(),
    ];
    if (parts.isNotEmpty) return parts.join(', ');
    return city ?? district ?? address ?? 'Manual location';
  }

  LocationRecord copyWith({
    String? id,
    Coordinates? coordinates,
    LocationMode? mode,
    String? label,
    String? city,
    String? district,
    String? state,
    String? pinCode,
    String? address,
    bool? isSelected,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LocationRecord(
      id: id ?? this.id,
      coordinates: coordinates ?? this.coordinates,
      mode: mode ?? this.mode,
      label: label ?? this.label,
      city: city ?? this.city,
      district: district ?? this.district,
      state: state ?? this.state,
      pinCode: pinCode ?? this.pinCode,
      address: address ?? this.address,
      isSelected: isSelected ?? this.isSelected,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}