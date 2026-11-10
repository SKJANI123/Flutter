import 'package:flutter/foundation.dart';

/// Central application configuration.
///
/// Values can be overridden at build/run time using `--dart-define`, e.g.:
///
/// ```sh
/// flutter run --dart-define=APP_ENV=prod \
///             --dart-define=API_BASE_URL=https://api.example.com \
///             --dart-define=WS_URL=wss://api.example.com/ws
/// ```
///
/// No secrets or API keys are ever hard-coded here.
class AppConfig {
  AppConfig._();

  static const String env = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'dev',
  );

  static const String _defaultBase = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.disaster-alert.example.com',
  );

  static const String _defaultWs = String.fromEnvironment(
    'WS_URL',
    defaultValue: 'wss://api.disaster-alert.example.com/ws',
  );

  static const String apiKey = String.fromEnvironment('API_KEY');

  static const String _defaultPollInterval = String.fromEnvironment(
    'POLL_INTERVAL_SECONDS',
    defaultValue: '30',
  );

  static String get baseUrl {
    final trimmed = _defaultBase.trimRight();
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }

  static String get wsUrl => _defaultWs;

  static bool get isProduction =>
      env.toLowerCase() == 'prod' || env.toLowerCase() == 'production';

  static bool get isDev => kDebugMode || !isProduction;

  static bool get simulatorEnabledByDefault => isDev;

  static int get pollIntervalSeconds =>
      int.tryParse(_defaultPollInterval) ?? 30;

  static int get requestTimeoutSeconds =>
      int.tryParse(
        const String.fromEnvironment(
          'REQUEST_TIMEOUT_SECONDS',
          defaultValue: '10',
        ),
      ) ??
      10;

  static Duration get requestTimeout =>
      Duration(seconds: requestTimeoutSeconds);

  /// How long an individual incident-feed poll may take before the source is
  /// marked unavailable. Generous on purpose: USGS/GDACS can be slow from
  /// congested or remote networks (observed 15-20s).
  static int get sourceTimeoutSeconds =>
      int.tryParse(
        const String.fromEnvironment(
          'SOURCE_TIMEOUT_SECONDS',
          defaultValue: '30',
        ),
      ) ??
      30;

  static Duration get sourceTimeout => Duration(seconds: sourceTimeoutSeconds);

  /// REST endpoints (no hard-coded secrets).
  static String get disastersEndpoint => '$baseUrl/v1/disasters';
  static String get sheltersEndpoint => '$baseUrl/v1/shelters';
  static String get sosEndpoint => '$baseUrl/v1/sos';
  static String get syncEndpoint => '$baseUrl/v1/sync';

  /// Path to the bundled data-source configuration (see
  /// `assets/config/data_sources.json`). All API endpoints and per-source
  /// parameters live here — nothing is hard-coded in UI code.
  static const String dataSourcesConfigAsset =
      'assets/config/data_sources.json';

  /// Official, keyless, government-authoritative incident APIs. Each base URL
  /// can be overridden with `--dart-define` so the same binary can point at a
  /// mirror or an internal gateway.
  static const String _usgsBase = String.fromEnvironment(
    'USGS_BASE_URL',
    defaultValue: 'https://earthquake.usgs.gov',
  );
  static const String _gdacsBase = String.fromEnvironment(
    'GDACS_BASE_URL',
    defaultValue: 'https://www.gdacs.org',
  );
  static const String _openMeteoBase = String.fromEnvironment(
    'OPEN_METEO_BASE_URL',
    defaultValue: 'https://api.open-meteo.com',
  );
  static const String _geocodingBase = String.fromEnvironment(
    'GEOCODING_BASE_URL',
    defaultValue: 'https://geocoding-api.open-meteo.com',
  );

  static String get usgsBaseUrl => _usgsBase;
  static String get gdacsBaseUrl => _gdacsBase;
  static String get openMeteoBaseUrl => _openMeteoBase;
  static String get geocodingBaseUrl => _geocodingBase;

  static const String _ingestInterval = String.fromEnvironment(
    'INGEST_INTERVAL_SECONDS',
    defaultValue: '180',
  );

  /// How often live sources are re-polled (in addition to the REST/WS path).
  static int get ingestIntervalSeconds => int.tryParse(_ingestInterval) ?? 180;

  static const bool backgroundRefreshEnabled = bool.fromEnvironment(
    'BACKGROUND_REFRESH_ENABLED',
    defaultValue: false,
  );

  static const int maxReconnectAttempts = 12;
  static const int maxSyncAttempts = 5;
}
