import 'package:disaster/core/config/app_config.dart';
import 'package:disaster/core/network/connectivity_service.dart';
import 'package:disaster/core/network/http_client.dart';
import 'package:disaster/core/notifications/local_notification_service.dart';
import 'package:disaster/core/storage/secure_store.dart';
import 'package:disaster/data/local/database/app_database.dart';
import 'package:disaster/data/local/repositories/alert_history_repository.dart';
import 'package:disaster/data/local/repositories/disaster_repository.dart';
import 'package:disaster/data/local/repositories/emergency_contact_repository.dart';
import 'package:disaster/data/local/repositories/location_repository.dart';
import 'package:disaster/data/local/repositories/settings_repository.dart';
import 'package:disaster/data/local/repositories/shelter_repository.dart';
import 'package:disaster/data/local/repositories/sos_event_repository.dart';
import 'package:disaster/data/local/repositories/sync_queue_repository.dart';
import 'package:disaster/data/local/repositories/user_repository.dart';
import 'package:disaster/data/remote/api/disaster_api_service.dart';
import 'package:disaster/data/remote/api/geocoding_service.dart';
import 'package:disaster/data/remote/api/weather_service.dart';
import 'package:disaster/data/remote/repositories/disaster_remote_repository.dart';
import 'package:disaster/data/remote/repositories/shelter_remote_repository.dart';
import 'package:disaster/data/simulator/disaster_simulator.dart';
import 'package:disaster/data/sources/incident_ingestion_service.dart';
import 'package:disaster/data/sources/source_config.dart';
import 'package:disaster/data/sources/source_health.dart';
import 'package:disaster/data/sync/sync_metadata_store.dart';
import 'package:disaster/data/sync/sync_service.dart';
import 'package:disaster/domain/repositories/alert_history_repository.dart'
    as domain;
import 'package:disaster/domain/repositories/disaster_repository.dart'
    as domain2;
import 'package:disaster/domain/repositories/emergency_contact_repository.dart'
    as domain3;
import 'package:disaster/domain/repositories/location_repository.dart'
    as domain8;
import 'package:disaster/domain/repositories/settings_repository.dart'
    as domain4;
import 'package:disaster/domain/repositories/shelter_repository.dart'
    as domain5;
import 'package:disaster/domain/repositories/sos_event_repository.dart'
    as domain6;
import 'package:disaster/domain/repositories/user_repository.dart' as domain7;
import 'package:disaster/domain/services/active_location.dart';
import 'package:disaster/domain/services/alert_pipeline.dart';
import 'package:disaster/domain/services/disaster_realtime_service.dart';
import 'package:disaster/domain/services/emergency_sos_service.dart';
import 'package:disaster/domain/services/location_service.dart';
import 'package:disaster/core/network/realtime_service.dart' as rt;

/// Central dependency graph for the app. Constructed once at bootstrap.
class AppDependencies {
  AppDependencies._({
    required this.db,
    required this.secureStore,
    required this.connectivity,
    required this.apiClient,
    required this.apiService,
    required this.disasterRemote,
    required this.shelterRemote,
    required this.localNotifications,
    required this.location,
    required this.syncQueue,
    required this.syncMetadata,
    required this.disasters,
    required this.history,
    required this.contacts,
    required this.shelters,
    required this.sosEvents,
    required this.settings,
    required this.users,
    required this.locations,
    required this.geocoder,
    required this.weather,
    required this.activeLocation,
    required this.sourceConfig,
    required this.sourceHealth,
    required this.ingestion,
    required this.syncService,
    required this.pipeline,
    required this.realtime,
    required this.realtimeService,
    required this.sos,
    required this.simulator,
  });

  final AppDatabase db;
  final SecureStore secureStore;
  final ConnectivityService connectivity;
  final ApiClient apiClient;
  final DisasterApiService apiService;
  final DisasterRemoteRepository disasterRemote;
  final ShelterRemoteRepository shelterRemote;
  final LocalNotificationService localNotifications;
  final LocationService location;

  final SyncQueueRepository syncQueue;
  final SyncMetadataStore syncMetadata;

  final domain2.DisasterRepository disasters;
  final domain.AlertHistoryRepository history;
  final domain3.EmergencyContactRepository contacts;
  final domain5.ShelterRepository shelters;
  final domain6.SosEventRepository sosEvents;
  final domain4.SettingsRepository settings;
  final domain7.UserRepository users;

  final domain8.LocationRepository locations;
  final GeocodingService geocoder;
  final WeatherService weather;
  final ActiveLocation activeLocation;
  final SourceConfig sourceConfig;
  final SourceHealthRegistry sourceHealth;
  final IncidentIngestionService ingestion;

  final SyncService syncService;
  final AlertPipeline pipeline;
  final rt.RealtimeService realtimeService;
  final DisasterRealtimeService realtime;
  final EmergencySosService sos;
  final DisasterSimulator simulator;

  bool _disposed = false;

  /// Builds the full dependency graph.
  static Future<AppDependencies> bootstrap({
    AppDatabase? dbOverride,
    SecureStore? secureOverride,
    ConnectivityService? connectivityOverride,
    ApiClient? apiClientOverride,
    LocationService? locationOverride,
    LocalNotificationService? notificationsOverride,
    DisasterApiService? apiServiceOverride,
    String? wsUrl,
  }) async {
    final db = dbOverride ?? await AppDatabase.open();

    final secureStore = secureOverride ?? SecureStore();
    final connectivity = connectivityOverride ?? ConnectivityService();
    final apiClient = apiClientOverride ?? ApiClient(secureStore: secureStore);
    final apiService =
        apiServiceOverride ?? DisasterApiService(apiClient);

    final disasterRemote = DisasterRemoteRepository(apiService);
    final shelterRemote = ShelterRemoteRepository(apiService);

    final localNotifications =
        notificationsOverride ?? LocalNotificationService();
    await localNotifications.initialize();

    final location = locationOverride ?? LocationService();

    final syncQueue = SyncQueueRepository(db);
    final syncMetadata = SyncMetadataStore(db);

    final disasters = LocalDisasterRepository(db);
    final history = LocalAlertHistoryRepository(db);
    final contacts = LocalEmergencyContactRepository(db);
    final shelters = LocalShelterRepository(db);
    final sosEvents = LocalSosEventRepository(db);
    final settings = LocalSettingsRepository(db);
    final users = LocalUserRepository(db);
    final locations = LocalLocationRepository(db);

    // Reference point used by the pipeline, ingestion and UI. Manual-location
    // mode makes the whole app work without any GPS permission.
    final activeLocation = ActiveLocation();

    final geocoder = GeocodingService(apiClient);
    final weather = WeatherService(apiClient);

    final pipeline = AlertPipeline(
      disasters: disasters,
      history: history,
      settings: settings,
      location: location,
      notifications: localNotifications,
      activeLocation: activeLocation,
    );

    final sourceConfig = await SourceConfig.load();
    final sourceHealth = SourceHealthRegistry();
    final ingestion = IncidentIngestionService(
      health: sourceHealth,
      pipeline: pipeline,
      metadata: syncMetadata,
      activeLocation: activeLocation,
      connectivity: connectivity,
      config: sourceConfig,
    );

    final syncService = SyncService(
      connectivity: connectivity,
      syncQueue: syncQueue,
      disasterRemote: disasterRemote,
      shelterRemote: shelterRemote,
      disasters: disasters,
      shelters: shelters,
      sosEvents: sosEvents,
      api: apiService,
      metadata: syncMetadata,
    );

    final realtimeService = rt.RealtimeService(
      url: wsUrl ?? AppConfig.wsUrl,
      headers: _buildWsHeaders(secureStore),
    );

    final realtime = DisasterRealtimeService(
      socket: realtimeService,
      remote: disasterRemote,
      pipeline: pipeline,
      connectivity: connectivity,
    );

    final sos = EmergencySosService(
      location: location,
      sosEvents: sosEvents,
      contacts: contacts,
      syncQueue: syncQueue,
      api: apiService,
      notifications: localNotifications,
      connectivity: connectivity,
    );

    final simulator = DisasterSimulator(
      pipeline: pipeline,
      disasters: disasters,
      centerLat: 21.17,
      centerLng: 72.83,
    );

    return AppDependencies._(
      db: db,
      secureStore: secureStore,
      connectivity: connectivity,
      apiClient: apiClient,
      apiService: apiService,
      disasterRemote: disasterRemote,
      shelterRemote: shelterRemote,
      localNotifications: localNotifications,
      location: location,
      syncQueue: syncQueue,
      syncMetadata: syncMetadata,
      disasters: disasters,
      history: history,
      contacts: contacts,
      shelters: shelters,
      sosEvents: sosEvents,
      settings: settings,
      users: users,
      locations: locations,
      geocoder: geocoder,
      weather: weather,
      activeLocation: activeLocation,
      sourceConfig: sourceConfig,
      sourceHealth: sourceHealth,
      ingestion: ingestion,
      syncService: syncService,
      pipeline: pipeline,
      realtimeService: realtimeService,
      realtime: realtime,
      sos: sos,
      simulator: simulator,
    );
  }

  static Map<String, String>? _buildWsHeaders(SecureStore store) {
    // Token is attached lazily here; reading it is async but the socket
    // service tolerates a missing Authorization header on connect/reconnect.
    return null;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    ingestion.dispose();
    realtime.dispose();
    syncService.dispose();
    pipeline.dispose();
    sos.dispose();
    apiClient.dispose();
    connectivity.dispose();
    db.close();
  }
}
