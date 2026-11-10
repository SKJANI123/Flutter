import 'package:flutter/material.dart';

import 'package:disaster/domain/entities/location_record.dart';

/// User-preferences backed by the `app_settings` SQLite table.
class AppSettings {
  /// Sentinel distinguishing "not provided" from "explicitly cleared (null)".
  static const _unset = Object();

  const AppSettings({
    this.notificationsEnabled = true,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.pushRemoteEnabled = true,
    this.alertRadiusKm = 25.0,
    this.minimumAlertLevel = 1,
    this.onboardingCompleted = false,
    this.simulatorEnabled = true,
    this.cacheRetentionDays = 7,
    this.themeMode = ThemeMode.system,
    this.languageCode = 'en',
    this.locationMode = LocationMode.gps,
    this.selectedLocationId,
    this.selectedDisasterTypes = const {
      'earthquake',
      'flood',
      'cyclone',
      'tsunami',
      'landslide',
      'wildfire',
      'heavy_rain',
      'lightning',
      'storm',
      'extreme_heat',
      'volcano',
    },
  });

  final bool notificationsEnabled;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final bool pushRemoteEnabled;
  final double alertRadiusKm;
  final int minimumAlertLevel;
  final bool onboardingCompleted;
  final bool simulatorEnabled;
  final int cacheRetentionDays;
  final ThemeMode themeMode;
  final String languageCode;
  final LocationMode locationMode;
  final String? selectedLocationId;
  final Set<String> selectedDisasterTypes;

  bool isTypeSelected(String typeId) => selectedDisasterTypes.contains(typeId);

  AppSettings copyWith({
    bool? notificationsEnabled,
    bool? soundEnabled,
    bool? vibrationEnabled,
    bool? pushRemoteEnabled,
    double? alertRadiusKm,
    int? minimumAlertLevel,
    bool? onboardingCompleted,
    bool? simulatorEnabled,
    int? cacheRetentionDays,
    ThemeMode? themeMode,
    String? languageCode,
    LocationMode? locationMode,
    Object? selectedLocationId = _unset,
    Set<String>? selectedDisasterTypes,
  }) {
    return AppSettings(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      pushRemoteEnabled: pushRemoteEnabled ?? this.pushRemoteEnabled,
      alertRadiusKm: alertRadiusKm ?? this.alertRadiusKm,
      minimumAlertLevel: minimumAlertLevel ?? this.minimumAlertLevel,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      simulatorEnabled: simulatorEnabled ?? this.simulatorEnabled,
      cacheRetentionDays: cacheRetentionDays ?? this.cacheRetentionDays,
      themeMode: themeMode ?? this.themeMode,
      languageCode: languageCode ?? this.languageCode,
      locationMode: locationMode ?? this.locationMode,
      selectedLocationId: identical(selectedLocationId, _unset)
          ? this.selectedLocationId
          : selectedLocationId as String?,
      selectedDisasterTypes:
          selectedDisasterTypes ?? this.selectedDisasterTypes,
    );
  }

  Map<String, dynamic> toJson() => {
    'notificationsEnabled': notificationsEnabled,
    'soundEnabled': soundEnabled,
    'vibrationEnabled': vibrationEnabled,
    'pushRemoteEnabled': pushRemoteEnabled,
    'alertRadiusKm': alertRadiusKm,
    'minimumAlertLevel': minimumAlertLevel,
    'onboardingCompleted': onboardingCompleted,
    'simulatorEnabled': simulatorEnabled,
    'cacheRetentionDays': cacheRetentionDays,
    'themeMode': themeMode.index,
    'languageCode': languageCode,
    'locationMode': locationMode.code,
    'selectedLocationId': selectedLocationId,
    'selectedDisasterTypes': selectedDisasterTypes.toList(),
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
      soundEnabled: json['soundEnabled'] as bool? ?? true,
      vibrationEnabled: json['vibrationEnabled'] as bool? ?? true,
      pushRemoteEnabled: json['pushRemoteEnabled'] as bool? ?? true,
      alertRadiusKm: (json['alertRadiusKm'] as num?)?.toDouble() ?? 25.0,
      minimumAlertLevel: (json['minimumAlertLevel'] as num?)?.toInt() ?? 1,
      onboardingCompleted: json['onboardingCompleted'] as bool? ?? false,
      simulatorEnabled: json['simulatorEnabled'] as bool? ?? false,
      cacheRetentionDays: (json['cacheRetentionDays'] as num?)?.toInt() ?? 7,
      themeMode:
          ThemeMode.values.asNameMap()[json['themeMode']] ??
          ThemeMode.values.elementAtOrNull(_asInt(json['themeMode'])) ??
          ThemeMode.system,
      languageCode: json['languageCode'] as String? ?? 'en',
      locationMode: LocationMode.fromCode(json['locationMode'] as String?),
      selectedLocationId: json['selectedLocationId'] as String?,
      selectedDisasterTypes:
          (json['selectedDisasterTypes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toSet() ??
          const {
            'earthquake',
            'flood',
            'cyclone',
            'tsunami',
            'landslide',
            'wildfire',
            'heavy_rain',
            'lightning',
            'storm',
            'extreme_heat',
            'volcano',
          },
    );
  }

  static int? _asInt(dynamic v) => v is int ? v : null;
}

extension _ElementAtOrNull on List<ThemeMode> {
  ThemeMode? elementAtOrNull(int? index) {
    if (index == null || index < 0 || index >= length) return null;
    return this[index];
  }
}
