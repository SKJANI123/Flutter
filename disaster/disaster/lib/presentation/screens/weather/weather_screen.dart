import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:disaster/data/remote/api/weather_service.dart';
import 'package:disaster/domain/value_objects/coordinates.dart';
import 'package:disaster/presentation/providers/app_dependencies.dart';
import 'package:disaster/presentation/providers/location_controller.dart';
import 'package:disaster/presentation/widgets/common.dart';

/// Live weather for the active location (current conditions + hourly + daily)
/// from the keyless Open-Meteo forecast API. Pure display — no lifecycle, no
/// extra state that a plain StatefulWidget wouldn't buy us.
class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key, Coordinates? forCoords})
    : coords = forCoords;

  /// When set, weather is fetched for this exact coordinate (used by e.g.
  /// alert detail). Otherwise the active GPS/manual location is used.
  final Coordinates? coords;

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  late Future<_WeatherBundle> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_WeatherBundle> _load() async {
    final deps = context.read<AppDependencies>();
    final coords = widget.coords;
    if (coords != null) {
      return _WeatherBundle(
        coords: coords,
        label: null,
        weather: await deps.weather.fetch(coords),
      );
    }
    final location = context.read<LocationController>().activeLocationCoords;
    final label = context.read<LocationController>().locationLabel;
    if (location == null) {
      throw const _WeatherError(
        'No location selected. Select a place or grant GPS access in Settings.',
      );
    }
    return _WeatherBundle(
      coords: location,
      label: label,
      weather: await deps.weather.fetch(location),
    );
  }

  void _retry() {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Weather')),
      body: FutureBuilder<_WeatherBundle>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _WeatherErrorView(
              error: snapshot.error,
              onRetry: _retry,
            );
          }
          final bundle = snapshot.data!;
          if (!bundle.weather.hasData) {
            return EmptyState(
              icon: Icons.thermostat,
              title: 'No weather data available.',
              subtitle: 'The forecast service returned no data for this place.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              final next = await _load();
              if (mounted) setState(() => _future = Future.value(next));
            },
            child: _WeatherBody(
              bundle: bundle,
              onRefresh: _retry,
            ),
          );
        },
      ),
    );
  }
}

class _WeatherBundle {
  const _WeatherBundle({
    required this.coords,
    required this.weather,
    this.label,
  });

  final Coordinates coords;
  final String? label;
  final CurrentWeather weather;
}

class _WeatherError implements Exception {
  const _WeatherError(this.message);
  final String message;

  @override
  String toString() => message;
}

class _WeatherErrorView extends StatelessWidget {
  const _WeatherErrorView({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final message = error is _WeatherError
        ? (error as _WeatherError).message
        : 'Could not reach the weather service. Check your connection and try again.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off,
              size: 64,
              color: Theme.of(context).colorScheme.error.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeatherBody extends StatelessWidget {
  const _WeatherBody({required this.bundle, required this.onRefresh});

  final _WeatherBundle bundle;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final current = bundle.weather.current;
    final hourly = bundle.weather.hourly;
    final daily = bundle.weather.daily;
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        if (bundle.label != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.place_outlined, size: 16),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  bundle.label!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (current != null) _CurrentConditions(current: current),
        const SizedBox(height: 16),
        _HourlyStrip(hourly: hourly),
        const SizedBox(height: 16),
        _DailyForecast(daily: daily),
        const SizedBox(height: 24),
        Center(
          child: Text(
            'Forecast · Open-Meteo',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _CurrentConditions extends StatelessWidget {
  const _CurrentConditions({required this.current});

  final WeatherCurrent current;

  @override
  Widget build(BuildContext context) {
    final code = current.code;
    final temp = current.temperatureC;
    final feels = current.apparentTemperatureC;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: code.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: code.color.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Icon(code.icon, color: code.color, size: 42),
          const SizedBox(height: 8),
          Text(
            code.label,
            style: TextStyle(
              color: code.color,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${temp.toStringAsFixed(1)}°C',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          if (feels != null) ...[
            const SizedBox(height: 2),
            Text(
              'Feels like ${feels.toStringAsFixed(0)}°C',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              _Stat(
                icon: Icons.water_drop_outlined,
                label: 'Humidity',
                value: '${current.humidity.toStringAsFixed(0)}%',
              ),
              _Stat(
                icon: Icons.air,
                label: 'Wind',
                value: '${current.windKmh.toStringAsFixed(0)} km/h',
              ),
              _Stat(
                icon: Icons.beach_access_outlined,
                label: 'Rain',
                value: '${current.precipitationMm.toStringAsFixed(1)} mm',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(
            icon,
            size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _HourlyStrip extends StatelessWidget {
  const _HourlyStrip({required this.hourly});

  final List<WeatherHourly> hourly;

  @override
  Widget build(BuildContext context) {
    final hours = hourly.take(24).toList();
    if (hours.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hourly',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 128,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: hours.length,
            itemBuilder: (context, i) {
              final h = hours[i];
              final code = h.code;
              final now = DateTime.now();
              final label = i == 0 && _sameHour(h.time, now)
                  ? 'Now'
                  : '${h.time.hour}:00';
              return Container(
                width: 84,
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 12)),
                    Icon(code.icon, color: code.color, size: 24),
                    Text(
                      '${h.temperatureC.toStringAsFixed(0)}°',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (h.precipitationProbability > 0)
                      Text(
                        '${h.precipitationProbability.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 11,
                          color: const Color(0xFF42A5F5),
                        ),
                      )
                    else
                      const SizedBox(height: 13),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  bool _sameHour(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day &&
      a.hour == b.hour;
}

class _DailyForecast extends StatelessWidget {
  const _DailyForecast({required this.daily});

  final List<WeatherDaily> daily;

  @override
  Widget build(BuildContext context) {
    if (daily.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '3-day forecast',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        for (final d in daily)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 78,
                  child: Text(
                    _dayLabel(d.date),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Icon(d.code.icon, color: d.code.color, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    d.code.label,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${d.tempMinC.toStringAsFixed(0)}° / '
                  '${d.tempMaxC.toStringAsFixed(0)}°',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _dayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final diff = day.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return weekdays[date.weekday - 1];
  }
}