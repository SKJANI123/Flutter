import 'package:disaster/core/config/app_config.dart';
import 'package:disaster/core/network/http_client.dart';
import 'package:disaster/data/remote/models/disaster_event.dart';
import 'package:disaster/data/remote/models/shelter_dto.dart';
import 'package:disaster/domain/entities/disaster.dart';
import 'package:disaster/domain/entities/shelter.dart';
import 'package:disaster/domain/entities/sos_event.dart';

/// REST API service for remote data. All failures surface as typed exceptions
/// which callers convert into safe UI / retry behaviour — never crashes.
class DisasterApiService {
  DisasterApiService(ApiClient client) : _client = client;

  final ApiClient _client;

  /// Fetches disasters updated since [since] (UTC). Malformed items are
  /// skipped, never thrown.
  Future<List<Disaster>> fetchDisasters({
    DateTime? since,
    double? minLat,
    double? minLng,
    double? maxLat,
    double? maxLng,
  }) async {
    final params = <String, String>{};
    if (since != null) params['since'] = since.toUtc().toIso8601String();
    if (minLat != null) params['min_lat'] = '$minLat';
    if (minLng != null) params['min_lng'] = '$minLng';
    if (maxLat != null) params['max_lat'] = '$maxLat';
    if (maxLng != null) params['max_lng'] = '$maxLng';
    final path = params.isEmpty
        ? AppConfig.disastersEndpoint
        : '${AppConfig.disastersEndpoint}?${Uri(queryParameters: params).query}';
    final body = await _client.get(path);
    return DisasterEventParser.tryParseList(body);
  }

  Future<List<Shelter>> fetchShelters({
    double? lat,
    double? lng,
    double? radiusKm,
  }) async {
    final params = <String, String>{};
    if (lat != null) params['lat'] = '$lat';
    if (lng != null) params['lng'] = '$lng';
    if (radiusKm != null) params['radius_km'] = '$radiusKm';
    final path = params.isEmpty
        ? AppConfig.sheltersEndpoint
        : '${AppConfig.sheltersEndpoint}?${Uri(queryParameters: params).query}';
    final body = await _client.get(path);
    return ShelterParser.tryParseList(body);
  }

  /// Publishes an SOS event. Returns true on 2xx, throws on failure.
  Future<bool> publishSos(SosEvent event) async {
    await _client.post(AppConfig.sosEndpoint, {
      'id': event.id,
      'latitude': event.latitude,
      'longitude': event.longitude,
      'accuracy': event.accuracy,
      'message': event.message,
      'contact_ids': event.contactIds,
      'captured_at': event.capturedAt?.toUtc().toIso8601String(),
    });
    return true;
  }

  /// Reports a batch of `disasterId`/`ackLevel` pairs as delivered.
  Future<bool> acknowledgeAlerts(List<Map<String, String>> acks) async {
    await _client.post('${AppConfig.baseUrl}/v1/alerts/ack', {'acked': acks});
    return true;
  }
}
