import 'package:flutter_test/flutter_test.dart';

import 'package:disaster/data/remote/api/weather_service.dart';
import 'package:disaster/data/weather/weather_code.dart';
import 'package:disaster/domain/enums/disaster_type.dart';
import 'package:disaster/domain/value_objects/coordinates.dart';
import 'package:disaster/presentation/screens/guide/survival_guide_screen.dart';

const _coords = Coordinates(21.17, 72.83);

void main() {
  group('WeatherService.parseForecast', () {
    test('parses a full CurrentWeather payload', () {
      final weather = WeatherService.parseForecast(
        {
          'current': {
            'time': '2026-09-28T10:30',
            'temperature_2m': 31.4,
            'apparent_temperature': 33.1,
            'relative_humidity_2m': 62,
            'weather_code': 3,
            'wind_speed_10m': 12.6,
            'precipitation': 0.2,
            'is_day': 1,
          },
          'hourly': {
            'time': ['2026-09-28T11:00', '2026-09-28T12:00'],
            'temperature_2m': [32.0, 33.0],
            'weather_code': [1, 2],
            'precipitation_probability': [10, 20],
          },
          'daily': {
            'time': ['2026-09-28'],
            'weather_code': [2],
            'temperature_2m_max': [34.0],
            'temperature_2m_min': [24.0],
            'precipitation_sum': [0.5],
          },
        },
        _coords,
      );

      expect(weather.hasData, isTrue);
      final current = weather.current!;
      expect(current.temperatureC, 31.4);
      expect(current.apparentTemperatureC, 33.1);
      expect(current.humidity, 62);
      expect(current.windKmh, 12.6);
      expect(current.isDay, isTrue);
      expect(current.code.label, 'Cloudy');

      expect(weather.hourly, hasLength(2));
      expect(weather.hourly.first.precipitationProbability, 10);
      expect(weather.daily, hasLength(1));
      expect(weather.daily.first.tempMaxC, 34.0);
      expect(weather.daily.first.precipitationSumMm, 0.5);
    });

    test('degrades gracefully on malformed payloads', () {
      final weather = WeatherService.parseForecast('nonsense', _coords);
      expect(weather.hasData, isFalse);
      expect(weather.hourly, isEmpty);
      expect(weather.daily, isEmpty);

      final halfBaked = WeatherService.parseForecast(
        {
          'current': {'temperature_2m': 'bad'},
          'hourly': {'time': 'not-a-list'},
        },
        _coords,
      );
      // A current map normalizes missing/bad numbers to 0 rather than crash.
      expect(halfBaked.current, isNotNull);
      expect(halfBaked.current!.temperatureC, 0);
      expect(halfBaked.hourly, isEmpty);
    });

    test('skips hourly points with unparseable timestamps', () {
      final weather = WeatherService.parseForecast(
        {
          'hourly': {
            'time': ['never', '2026-09-28T12:00'],
            'temperature_2m': [1.0, 2.0],
            'weather_code': [0, 0],
            'precipitation_probability': [0, 0],
          },
        },
        _coords,
      );
      expect(weather.hourly, hasLength(1));
      expect(weather.hourly.single.time.hour, 12);
    });
  });

  group('WeatherCodes', () {
    test('maps WMO codes to weather info', () {
      expect(WeatherCodes.infoFor(0).label, 'Clear');
      expect(WeatherCodes.infoFor(80).label, 'Showers');
      expect(WeatherCodes.infoFor(95).label, 'Thunderstorm');
      expect(WeatherCodes.infoFor(999).label, 'Thunderstorm');
      expect(WeatherCodes.infoFor(-1).label, 'Weather');
    });
  });

  group('Survival Guide data', () {
    test('every hazard has before, during and after steps', () {
      expect(GuideData.guides, isNotEmpty);
      for (final guide in GuideData.guides) {
        expect(guide.id, isNotEmpty, reason: '${guide.title} needs an id');
        expect(
          guide.before,
          isNotEmpty,
          reason: '${guide.title} needs "before" steps',
        );
        expect(
          guide.during,
          isNotEmpty,
          reason: '${guide.title} needs "during" steps',
        );
        expect(
          guide.after,
          isNotEmpty,
          reason: '${guide.title} needs "after" steps',
        );
      }
    });

    test('ids are unique', () {
      final ids = GuideData.guides.map((g) => g.id).toSet();
      expect(ids.length, GuideData.guides.length);
    });

    test('lookup helpers work', () {
      expect(GuideData.byId('earthquake')?.title, 'Earthquake');
      expect(GuideData.byId('missing'), isNull);
      expect(GuideData.byType(DisasterType.earthquake)?.id, 'earthquake');
    });
  });
}