import 'package:disaster/core/errors/exceptions.dart';
import 'package:disaster/data/remote/api/disaster_api_service.dart';
import 'package:disaster/domain/entities/shelter.dart';

class ShelterRemoteRepository {
  ShelterRemoteRepository(this._api);

  final DisasterApiService _api;

  Future<List<Shelter>> fetchShelters({
    double? lat,
    double? lng,
    double? radiusKm,
  }) async {
    try {
      return await _api.fetchShelters(lat: lat, lng: lng, radiusKm: radiusKm);
    } on ApiException {
      rethrow;
    } on NetworkException {
      rethrow;
    } catch (_) {
      throw const ParseException('Could not parse shelter response');
    }
  }
}
