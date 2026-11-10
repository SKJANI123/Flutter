import 'package:disaster/core/config/app_config.dart';
import 'package:disaster/core/network/http_client.dart';
import 'package:disaster/data/weather/weather_code.dart';
import 'package:disaster/domain/value_objects/coordinates.dart';

/// One current-condition observation.
class WeatherCurrent {
  const WeatherCurrent({
    required this.time,
    required this.temperatureC,
    required this.weatherCode,
    required this.humidity,
    required this.windKmh,
    required this.precipitationMm,
    required this.isDay,
    this.apparentTemperatureC,
  });

  final DateTime time;
  final double temperatureC;
  final int weatherCode;
  final double humidity;
  final double windKmh;
  final double precipitationMm;
  final bool isDay;
  final double? apparentTemperatureC;

  WeatherCodeInfo get code => WeatherCodes.infoFor(weatherCode);
}

/// One hourly forecast point.
class WeatherHourly {
  const WeatherHourly({
    required this.time,
    required this.temperatureC,
    required this.weatherCode,
    required this.precipitationProbability,
  });

  final DateTime time;
  final double temperatureC;
  final int weatherCode;
  final double precipitationProbability;

  WeatherCodeInfo get code => WeatherCodes.infoFor(weatherCode);
}

/// One daily forecast point.
class WeatherDaily {
  const WeatherDaily({
    required this.date,
    required this.weatherCode,
    required this.tempMaxC,
    required this.tempMinC,
    required this.precipitationSumMm,
  });

  final DateTime date;
  final int weatherCode;
  final double tempMaxC;
  final double tempMinC;
  final double precipitationSumMm;

  WeatherCodeInfo get code => WeatherCodes.infoFor(weatherCode);
}

/// Full forecast for one place.
class CurrentWeather {
  const CurrentWeather({
    required this.coordinates,
    required this.current,
    required this.hourly,
    required this.daily,
  });

  final Coordinates coordinates;
  final WeatherCurrent? current;
  final List<WeatherHourly> hourly;
  final List<WeatherDaily> daily;

  bool get hasData => current != null || hourly.isNotEmpty || daily.isNotEmpty;
}

/// Keyless Open-Meteo weather: current conditions + hourly + daily forecast.
///
/// This powers the Weather screen (not the alert pipeline, which derives
/// severe-weather WARNINGS from the same API via [OpenMeteoWeatherSource]).
class WeatherService {
  WeatherService(this._client);

  final ApiClient _client;

  Future<CurrentWeather> fetch(
    Coordinates coords, {
    String language = 'en',
    int forecastDays = 3,
  }) async {
    final base = Uri.parse(AppConfig.openMeteoBaseUrl);
    final uri = Uri(
      scheme: base.scheme,
      host: base.host,
      path: '${base.path}/v1/forecast',
      queryParameters: {
        'latitude': coords.latitude.toString(),
        'longitude': coords.longitude.toString(),
        'current':
            'temperature_2m,apparent_temperature,relative_humidity_2m,'
            'weather_code,wind_speed_10m,precipitation,is_day',
        'hourly': 'temperature_2m,weather_code,precipitation_probability',
        'daily':
            'weather_code,temperature_2m_max,temperature_2m_min,'
            'precipitation_sum',
        'timezone': 'auto',
        'forecast_days': '$forecastDays',
        'language': language,
      },
    );
    final body = await _client.get(
      uri.toString(),
      timeout: AppConfig.sourceTimeout,
    );
    return parseForecast(body, coords);
  }

  /// Public parser for tests. Malformed payloads degrade gracefully.
  static CurrentWeather parseForecast(dynamic raw, Coordinates coords) {
    if (raw is! Map<String, dynamic>) {
      return CurrentWeather(
        coordinates: coords,
        current: null,
        hourly: const [],
        daily: const [],
      );
    }

    final currentRaw = raw['current'];
    WeatherCurrent? current;
    if (currentRaw is Map<String, dynamic>) {
      current = WeatherCurrent(
        time: _dateOrEpoch(currentRaw['time']),
        temperatureC: _num(currentRaw['temperature_2m']),
        apparentTemperatureC: _nullableNum(
          currentRaw['apparent_temperature'],
        ),
        weatherCode: _num(currentRaw['weather_code']).toInt(),
        humidity: _num(currentRaw['relative_humidity_2m']),
        windKmh: _num(currentRaw['wind_speed_10m']),
        precipitationMm: _num(currentRaw['precipitation']),
        isDay: _num(currentRaw['is_day']).toInt() == 1,
      );
    }

    final hourly = <WeatherHourly>[];
    final hourlyRaw = raw['hourly'];
    if (hourlyRaw is Map<String, dynamic>) {
      final times = hourlyRaw['time'];
      final temps = hourlyRaw['temperature_2m'];
      final codes = hourlyRaw['weather_code'];
      final probs = hourlyRaw['precipitation_probability'];
      if (times is List && temps is List && codes is List) {
        for (var i = 0; i < times.length; i++) {
          if (i >= temps.length || i >= codes.length) break;
          final time = _parseIso(times[i]);
          if (time == null) continue;
          hourly.add(
            WeatherHourly(
              time: time,
              temperatureC: (temps[i] as num).toDouble(),
              weatherCode: (codes[i] as num).toInt(),
              precipitationProbability:
                  probs is List && i < probs.length && probs[i] is num
                  ? (probs[i] as num).toDouble()
                  : 0,
            ),
          );
        }
      }
    }

    final daily = <WeatherDaily>[];
    final dailyRaw = raw['daily'];
    if (dailyRaw is Map<String, dynamic>) {
      final dates = dailyRaw['time'];
      final maxes = dailyRaw['temperature_2m_max'];
      final mins = dailyRaw['temperature_2m_min'];
      final codes = dailyRaw['weather_code'];
      final precip = dailyRaw['precipitation_sum'];
      if (dates is List && maxes is List && mins is List && codes is List) {
        for (var i = 0; i < dates.length; i++) {
          if (i >= maxes.length || i >= mins.length || i >= codes.length) {
            break;
          }
          final date = _parseIso(dates[i]);
          if (date == null) continue;
          daily.add(
            WeatherDaily(
              date: date,
              weatherCode: (codes[i] as num).toInt(),
              tempMaxC: (maxes[i] as num).toDouble(),
              tempMinC: (mins[i] as num).toDouble(),
              precipitationSumMm:
                  precip is List && i < precip.length && precip[i] is num
                  ? (precip[i] as num).toDouble()
                  : 0,
            ),
          );
        }
      }
    }

    return CurrentWeather(
      coordinates: coords,
      current: current,
      hourly: hourly,
      daily: daily,
    );
  }

  static double _num(Object? v) => v is num ? v.toDouble() : 0;
  static double? _nullableNum(Object? v) => v is num ? v.toDouble() : null;
  static DateTime _dateOrEpoch(Object? v) {
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v, isUtc: true);
    return _parseIso(v) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  static DateTime? _parseIso(Object? v) {
    final s = v?.toString();
    if (s == null || s.isEmpty) return null;
    final parsed = DateTime.tryParse(s);
    return parsed?.toLocal();
  }
}