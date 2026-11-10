import 'package:disaster/core/config/app_config.dart';
import 'package:disaster/core/network/http_client.dart';
import 'package:disaster/domain/value_objects/coordinates.dart';

/// One candidate returned by the geocoder.
class GeocodeResult {
  const GeocodeResult({
    required this.name,
    required this.coordinates,
    required this.countryCode,
    this.country,
    this.state,
    this.district,
    this.postcodes = const [],
  });

  final String name;
  final Coordinates coordinates;
  final String countryCode;
  final String? country;
  final String? state;
  final String? district;
  final List<String> postcodes;

  String get summary => [
    name,
    state,
    country,
    postcodes.isNotEmpty ? postcodes.first : null,
  ].whereType<String>().where((s) => s.trim().isNotEmpty).join(', ');
}

/// Converts free-form place text (city / district / state / PIN / address)
/// into coordinates using the keyless official Open-Meteo Geocoding API.
///
/// Used by manual location mode so the whole app works without any GPS
/// permission. Failures surface as typed exceptions and never crash.
class GeocodingService {
  GeocodingService(this._client);

  final ApiClient _client;

  Future<List<GeocodeResult>> search(
    String query, {
    int count = 6,
    String language = 'en',
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    final base = '${AppConfig.geocodingBaseUrl}/v1/search';
    final uri = Uri(
      scheme: 'https',
      host: Uri.parse(base).host,
      path: Uri.parse(base).path,
      queryParameters: {
        'name': trimmed,
        'count': '$count',
        'language': language,
        'format': 'json',
      },
    );
    final body = await _client.get(uri.toString());
    return parseResults(body);
  }

  /// Public parser for tests. Malformed entries are skipped.
  static List<GeocodeResult> parseResults(dynamic raw) {
    if (raw is! Map<String, dynamic>) return const [];
    final results = raw['results'];
    if (results is! List) return const [];
    final out = <GeocodeResult>[];
    for (final r in results) {
      if (r is! Map<String, dynamic>) continue;
      final lat = (r['latitude'] is num)
          ? (r['latitude'] as num).toDouble()
          : null;
      final lng = (r['longitude'] is num)
          ? (r['longitude'] as num).toDouble()
          : null;
      if (lat == null || lng == null) continue;
      final countryCode = (r['country_code'] as String?) ?? '??';
      try {
        out.add(
          GeocodeResult(
            name: (r['name'] as String?) ?? 'Unknown place',
            coordinates: Coordinates(lat, lng),
            countryCode: countryCode,
            country: r['country'] as String?,
            state: r['admin1'] as String?,
            district: r['admin2'] as String?,
            postcodes:
                (r['postcodes'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList() ??
                const [],
          ),
        );
      } on ArgumentError {
        // Skip entries with out-of-range coordinates.
      }
    }
    return out;
  }
}
