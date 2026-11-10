import 'package:disaster/domain/entities/shelter.dart';
import 'package:disaster/domain/value_objects/coordinates.dart';

/// Parses raw shelter payloads into [Shelter] models, tolerating missing or
/// malformed fields.
class ShelterParser {
  ShelterParser._();

  static List<Shelter> tryParseList(dynamic raw) {
    if (raw is! Map<String, dynamic>) return const [];
    final items = raw['shelters'] ?? raw['data'] ?? raw['places'];
    if (items is! List) return const [];
    return items.map(_tryParseSingle).whereType<Shelter>().toList();
  }

  static Shelter? _tryParseSingle(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;
    final id = raw['id'];
    final lat = _asDouble(raw['latitude'] ?? raw['lat']);
    final lng = _asDouble(raw['longitude'] ?? raw['lng'] ?? raw['lon']);
    if (id == null || lat == null || lng == null) return null;
    return Shelter(
      id: id.toString(),
      name: _asString(raw['name']) ?? 'Safe place',
      address: _asString(raw['address']),
      coordinates: Coordinates(lat, lng),
      phone: _asString(raw['phone']),
      type: SafePlaceType.fromCode(_asString(raw['type'])),
      capacity: raw['capacity'] is num
          ? (raw['capacity'] as num).toInt()
          : null,
      isOpen: raw['is_open'] is bool ? raw['is_open'] as bool : true,
      source: _asString(raw['source']) ?? 'server',
    );
  }

  static String? _asString(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static double? _asDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}
