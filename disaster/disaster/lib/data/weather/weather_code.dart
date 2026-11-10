import 'package:flutter/material.dart';

import 'package:disaster/presentation/theme/app_theme.dart';

/// Presentational info for a WMO weather-interpretation code (from
/// Open-Meteo): label, short description, icon and severity colour. Handy for
/// the Weather screen and reusable anywhere weather is shown.
class WeatherCodeInfo {
  const WeatherCodeInfo({
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
  });

  final String label;
  final String description;
  final IconData icon;
  final Color color;
}

class WeatherCodes {
  WeatherCodes._();

  static const _clear = WeatherCodeInfo(
    label: 'Clear',
    description: 'Clear skies',
    icon: Icons.wb_sunny_outlined,
    color: Color(0xFFFFC53D),
  );
  static const _cloudy = WeatherCodeInfo(
    label: 'Cloudy',
    description: 'Partly cloudy',
    icon: Icons.cloud_outlined,
    color: Color(0xFFB0BEC5),
  );
  static const _fog = WeatherCodeInfo(
    label: 'Fog',
    description: 'Reduced visibility',
    icon: Icons.blur_on,
    color: Color(0xFF90A4AE),
  );
  static const _drizzle = WeatherCodeInfo(
    label: 'Drizzle',
    description: 'Light rain',
    icon: Icons.grain,
    color: AppTheme.info,
  );
  static const _rain = WeatherCodeInfo(
    label: 'Rain',
    description: 'Moderate to heavy rain',
    icon: Icons.water_drop_outlined,
    color: AppTheme.info,
  );
  static const _snow = WeatherCodeInfo(
    label: 'Snow',
    description: 'Snowfall',
    icon: Icons.ac_unit,
    color: Colors.lightBlueAccent,
  );
  static const _showers = WeatherCodeInfo(
    label: 'Showers',
    description: 'Passing showers',
    icon: Icons.umbrella_outlined,
    color: AppTheme.info,
  );
  static const _storm = WeatherCodeInfo(
    label: 'Thunderstorm',
    description: 'Storm with lightning',
    icon: Icons.thunderstorm_outlined,
    color: AppTheme.warningA,
  );
  static const _unknown = WeatherCodeInfo(
    label: 'Weather',
    description: 'Conditions unknown',
    icon: Icons.thermostat_outlined,
    color: AppTheme.secondary,
  );

  static WeatherCodeInfo infoFor(int code) {
    if (code == 0) return _clear;
    if (code >= 1 && code <= 3) return _cloudy;
    if (code == 45 || code == 48) return _fog;
    if (code >= 51 && code <= 57) return _drizzle;
    if (code >= 56 && code <= 67) return _rain;
    if (code >= 61 && code <= 65) return _rain;
    if (code >= 71 && code <= 77) return _snow;
    if (code >= 80 && code <= 84) return _showers;
    if (code >= 85 && code <= 86) return _snow;
    if (code >= 95) return _storm;
    return _unknown;
  }
}