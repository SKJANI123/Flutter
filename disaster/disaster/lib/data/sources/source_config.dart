import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'package:disaster/core/config/app_config.dart';

/// Per-source runtime configuration, loaded from the bundled
/// `assets/config/data_sources.json` (and overridable via `--dart-define`).
///
/// The file defines *which* official sources are enabled and their tuning
/// parameters. Endpoint base URLs and any API keys come from environment
/// variables (`AppConfig`), never from UI code.
class SourceConfigEntry {
  const SourceConfigEntry({
    required this.id,
    required this.name,
    required this.description,
    required this.kind,
    required this.enabled,
    this.params = const {},
  });

  final String id;
  final String name;
  final String description;
  final String kind;
  final bool enabled;
  final Map<String, dynamic> params;

  bool get enabledByDefault => enabled;

  /// Value typed out of [params]; [fallback] used when missing or not
  /// convertible.
  double paramDouble(String key, double fallback) {
    final v = params[key];
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fallback;
    return fallback;
  }

  int paramInt(String key, int fallback) {
    final v = params[key];
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  String paramString(String key, String fallback) {
    final v = params[key];
    if (v is String && v.isNotEmpty) return v;
    return fallback;
  }

  factory SourceConfigEntry.fromJson(Map<String, dynamic> json) {
    return SourceConfigEntry(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      kind: json['kind'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? false,
      params: (json['params'] as Map<String, dynamic>?) ?? const {},
    );
  }
}

/// Parsed `data_sources.json` + built-in defaults when the asset is missing.
class SourceConfig {
  const SourceConfig({required this.sources});

  final List<SourceConfigEntry> sources;

  SourceConfigEntry? byId(String id) {
    for (final s in sources) {
      if (s.id == id) return s;
    }
    return null;
  }

  List<SourceConfigEntry> get enabled =>
      sources.where((s) => s.enabled).toList();

  /// Defaults matching the bundled asset; used when the asset cannot be read
  /// so the app still boots with sensible, real sources.
  static const SourceConfig defaults = SourceConfig(
    sources: [
      SourceConfigEntry(
        id: 'usgs',
        name: 'USGS',
        description: 'U.S. Geological Survey — official earthquake monitoring.',
        kind: 'earthquakes',
        enabled: true,
        params: {'minMagnitude': 5.0, 'maxAgeHours': 48.0, 'limit': 100, 'geoRadiusKm': 2000.0},
      ),
      SourceConfigEntry(
        id: 'gdacs',
        name: 'GDACS',
        description:
            'United Nations Global Disaster Alert and Coordination System.',
        kind: 'disasters',
        enabled: true,
        params: {'maxAgeDays': 30, 'minAlertLevel': 'green', 'geoRadiusKm': 2000.0},
      ),
      SourceConfigEntry(
        id: 'open_meteo_weather',
        name: 'Open-Meteo',
        description:
            'National weather-model forecasts — severe weather from WMO codes.',
        kind: 'weather_warnings',
        enabled: true,
        params: {'forecastDays': 2, 'minWmoCode': 61},
      ),
    ],
  );

  /// Loads configuration from the bundled asset, falling back to [defaults]
  /// if it is missing or malformed. Never throws.
  static Future<SourceConfig> load() async {
    try {
      final raw = await rootBundle.loadString(AppConfig.dataSourcesConfigAsset);
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final list = decoded['sources'] as List<dynamic>? ?? const [];
      final sources = list
          .map(
            (e) => e is Map<String, dynamic>
                ? SourceConfigEntry.fromJson(e)
                : null,
          )
          .whereType<SourceConfigEntry>()
          .toList();
      if (sources.isEmpty) return defaults;
      return SourceConfig(sources: sources);
    } catch (_) {
      return defaults;
    }
  }
}
