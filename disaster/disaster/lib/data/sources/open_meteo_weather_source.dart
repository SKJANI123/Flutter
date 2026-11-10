import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:disaster/core/config/app_config.dart';
import 'package:disaster/data/sources/disaster_source.dart';
import 'package:disaster/data/sources/source_config.dart';
import 'package:disaster/domain/entities/disaster.dart';
import 'package:disaster/domain/enums/disaster_status.dart';
import 'package:disaster/domain/enums/disaster_type.dart';
import 'package:disaster/domain/enums/severity.dart';
import 'package:disaster/domain/value_objects/coordinates.dart';

/// Official national weather-model forecasts (MET Norway / DWD / ECMWF via
/// Open-Meteo) converted into severe-weather incident alerts using the WMO
/// weather-code standard. Location-based: anchored at the user's active
/// reference point (manual or GPS).
///
/// Endpoint overridable via `--dart-define=OPEN_METEO_BASE_URL=...`.
class OpenMeteoWeatherSource implements DisasterSource {
  OpenMeteoWeatherSource({required this.config, http.Client? client})
    : _injectedClient = client;

  final SourceConfigEntry config;
  final http.Client? _injectedClient;

  @override
  String get id => config.id;

  @override
  String get name => config.name;

  @override
  String get description => config.description;

  int get forecastDays => config.paramInt('forecastDays', 2);
  double get heatThresholdC => config.paramDouble('heatThresholdC', 45.0);

  @override
  Future<SourceFetchResult> fetch({
    DateTime? since,
    Coordinates? referencePoint,
  }) async {
    // No reference point => nothing to scope weather warnings against. This is
    // not an error: the source simply cannot produce meaningful incidents.
    final actual = referencePoint;
    if (actual == null) {
      return SourceFetchResult(sourceId: id, incidents: const []);
    }
    final uri = Uri(
      scheme: 'https',
      host: Uri.parse(AppConfig.openMeteoBaseUrl).host,
      path: '/v1/forecast',
      queryParameters: {
        'latitude': '${actual.latitude}',
        'longitude': '${actual.longitude}',
        'daily': 'weather_code,temperature_2m_max',
        'forecast_days': '$forecastDays',
        'timezone': 'auto',
      },
    );
    final http.Client client = _injectedClient ?? http.Client();
    try {
      final res = await client.get(uri).timeout(AppConfig.sourceTimeout);
      if (res.statusCode != 200) {
        throw SourceUnavailableException(
          id,
          'Open-Meteo responded with ${res.statusCode}',
        );
      }
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      return SourceFetchResult(
        sourceId: id,
        incidents: parse(
          body,
          referencePoint: actual,
          forecastDays: forecastDays,
          heatThresholdC: heatThresholdC,
        ),
        fetchedAt: DateTime.now().toUtc(),
      );
    } on SourceUnavailableException {
      rethrow;
    } on Object catch (e) {
      throw SourceUnavailableException(id, 'Open-Meteo request failed', e);
    } finally {
      if (_injectedClient == null) client.close();
    }
  }

  /// Public parser for tests. Converts a raw `/v1/forecast` response into
  /// severe-weather [Disaster] incidents.
  static List<Disaster> parse(
    Object? raw, {
    required Coordinates referencePoint,
    int forecastDays = 2,
    double heatThresholdC = 45.0,
  }) {
    if (raw is! Map<String, dynamic>) return const [];
    final daily = raw['daily'];
    if (daily is! Map<String, dynamic>) return const [];
    final times = daily['time'] as List<dynamic>?;
    final codes = daily['weather_code'] as List<dynamic>?;
    final temps = daily['temperature_2m_max'] as List<dynamic>?;
    if (times == null || codes == null || times.length != codes.length) {
      return const [];
    }
    final out = <Disaster>[];
    for (var i = 0; i < times.length; i++) {
      final iso = times[i]?.toString();
      final day = iso == null ? null : DateTime.tryParse(iso);
      final code = codes[i] is num ? (codes[i] as num).toInt() : null;
      if (code == null) continue;
      final warning = _warningFor(code);
      final startOfDay = day ?? DateTime.now();
      final endOfDay = startOfDay.add(const Duration(hours: 23, minutes: 59));
      if (warning != null) {
        out.add(
          Disaster(
            id: 'owm_${_safeDigest(iso ?? '$i', code)}',
            type: warning.$1,
            title: warning.$2,
            description: _describe(code),
            coordinates: referencePoint,
            affectedRadiusKm: code >= 95 ? 60.0 : 100.0,
            severity: warning.$3,
            status: DisasterStatus.active,
            occurredAt: startOfDay,
            expiresAt: endOfDay,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            source: 'Open-Meteo',
            area: 'Around your location',
            provider: DataProvider.server,
            payloadHash: _safeDigest('$iso|$code', code),
          ),
        );
      }
      // Extreme-heat advisory from the official daily max temperature.
      if (temps != null && i < temps.length) {
        final t = temps[i] is num ? (temps[i] as num).toDouble() : null;
        if (t != null && t >= heatThresholdC) {
          out.add(
            Disaster(
              id: 'owm_heat_${_safeDigest(iso ?? '$i', 999)}',
              type: DisasterType.extremeHeat,
              title: 'Extreme Heat Warning',
              description:
                  'Maximum temperature forecast to reach ${t.toStringAsFixed(1)}°C, which exceeds the extreme-heat threshold.',
              coordinates: referencePoint,
              affectedRadiusKm: 120.0,
              severity: Severity.severe,
              status: DisasterStatus.active,
              occurredAt: startOfDay,
              expiresAt: endOfDay,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              source: 'Open-Meteo',
              area: 'Around your location',
              provider: DataProvider.server,
              payloadHash: _safeDigest('heat|$iso', 998),
            ),
          );
        }
      }
    }
    return out;
  }

  static (DisasterType, String, Severity)? _warningFor(int wmoCode) {
    switch (wmoCode) {
      case 63:
      case 64:
        return (
          DisasterType.heavyRain,
          'Heavy Rain Warning',
          Severity.moderate,
        );
      case 65:
      case 66:
      case 67:
        return (DisasterType.heavyRain, 'Heavy Rain Warning', Severity.severe);
      case 71:
      case 73:
        return (DisasterType.storm, 'Winter Storm Warning', Severity.moderate);
      case 75:
      case 85:
      case 86:
        return (DisasterType.storm, 'Heavy Snow Warning', Severity.severe);
      case 80:
      case 81:
        return (
          DisasterType.heavyRain,
          'Heavy Rain Showers Warning',
          Severity.moderate,
        );
      case 82:
        return (
          DisasterType.heavyRain,
          'Violent Rain Showers Warning',
          Severity.severe,
        );
      case 95:
        return (
          DisasterType.lightning,
          'Thunderstorm Warning',
          Severity.moderate,
        );
      case 96:
      case 99:
        return (
          DisasterType.lightning,
          'Severe Thunderstorm Warning',
          Severity.severe,
        );
      default:
        return null;
    }
  }

  static String _describe(int code) {
    switch (code) {
      case 95:
      case 96:
      case 99:
        return 'Thunderstorms with possible hail are forecast for this area.';
      case 63:
      case 64:
      case 65:
      case 80:
      case 81:
      case 82:
        return 'Significant rainfall is forecast; localised flooding is possible.';
      case 66:
      case 67:
        return 'Freezing rain is forecast; travel surfaces will be hazardous.';
      case 71:
      case 73:
      case 75:
      case 85:
      case 86:
        return 'Significant snowfall is forecast; accumulations may disrupt travel.';
      default:
        return 'Severe weather conditions are forecast for this area.';
    }
  }

  /// Short, unique suffix for ids/payload hashes.
  static String _safeDigest(String input, int seed) =>
      input.replaceAll(RegExp('[^A-Za-z0-9]'), '_').isEmpty
      ? '$seed'
      : '${input.replaceAll(RegExp('[^A-Za-z0-9]'), '_')}_$seed';
}
