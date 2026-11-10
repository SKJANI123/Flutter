import 'package:disaster/core/errors/exceptions.dart';
import 'package:disaster/core/network/http_client.dart';
import 'package:disaster/core/notifications/local_notification_service.dart';
import 'package:disaster/data/remote/api/disaster_api_service.dart';
import 'package:disaster/domain/entities/disaster.dart';
import 'package:disaster/domain/entities/shelter.dart';
import 'package:disaster/domain/entities/sos_event.dart';
import 'package:disaster/domain/services/location_service.dart';
import 'package:disaster/domain/value_objects/coordinates.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Returns a fixed location instead of talking to the GPS plugin.
class FakeLocationService extends LocationService {
  FakeLocationService({this.fixed});

  final Coordinates? fixed;

  @override
  Future<Coordinates?> getCurrentLocation() async => fixed;

  @override
  Future<Coordinates?> getLastKnownLocation() async => fixed;
}

/// Records alert notifications instead of showing the OS notifications.
class FakeNotificationService extends LocalNotificationService {
  FakeNotificationService() : super();

  final List<String> shown = <String>[];
  bool shouldSucceed = true;

  @override
  Future<bool> initialize() async => true;

  @override
  Future<bool> showAlert({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    shown.add('$id|$title');
    return shouldSucceed;
  }
}

/// Deterministic REST API double for sync tests.
class FakeApiService extends DisasterApiService {
  FakeApiService()
    : super(
        ApiClient(
          overrideClient: MockClient((_) async => http.Response('{}', 200)),
        ),
      );

  List<Disaster> disasters = <Disaster>[];
  List<Shelter> shelters = <Shelter>[];
  Object? disastersError;
  Object? sheltersError;
  bool failOutbox = false;
  final List<SosEvent> publishedSos = <SosEvent>[];
  final List<Map<String, String>> acks = <Map<String, String>>[];

  @override
  Future<List<Disaster>> fetchDisasters({
    DateTime? since,
    double? minLat,
    double? minLng,
    double? maxLat,
    double? maxLng,
  }) async {
    if (disastersError != null) throw disastersError!;
    return disasters;
  }

  @override
  Future<List<Shelter>> fetchShelters({
    double? lat,
    double? lng,
    double? radiusKm,
  }) async {
    if (sheltersError != null) throw sheltersError!;
    return shelters;
  }

  @override
  Future<bool> publishSos(SosEvent event) async {
    if (failOutbox) throw const NetworkException('offline');
    publishedSos.add(event);
    return true;
  }

  @override
  Future<bool> acknowledgeAlerts(List<Map<String, String>> acksList) async {
    if (failOutbox) throw const NetworkException('offline');
    acks.addAll(acksList);
    return true;
  }
}
