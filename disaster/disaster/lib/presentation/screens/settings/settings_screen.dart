import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:disaster/domain/entities/app_settings.dart';
import 'package:disaster/domain/enums/disaster_type.dart';
import 'package:disaster/presentation/providers/app_controller.dart';
import 'package:disaster/presentation/providers/app_dependencies.dart';
import 'package:disaster/presentation/providers/location_controller.dart';
import 'package:disaster/presentation/screens/contacts/contacts_screen.dart';
import 'package:disaster/presentation/screens/guide/survival_guide_screen.dart';
import 'package:disaster/presentation/screens/history/history_screen.dart';
import 'package:disaster/presentation/screens/live_alerts/live_alerts_screen.dart';
import 'package:disaster/presentation/screens/location/location_picker_screen.dart';
import 'package:disaster/presentation/screens/shelters/shelters_screen.dart';
import 'package:disaster/presentation/screens/weather/weather_screen.dart';
import 'package:disaster/presentation/theme/app_theme.dart';

/// The More tab: preferences, permissions, developer simulator and about.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings & More')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _RealtimeStatus(),
          SizedBox(height: 12),
          _LocationSection(),
          SizedBox(height: 12),
          _SafetySection(),
          SizedBox(height: 12),
          _NotificationsSection(),
          SizedBox(height: 12),
          _ThemeSection(),
          SizedBox(height: 12),
          _MoreLinks(),
          SizedBox(height: 12),
          _SimulatorSection(),
          SizedBox(height: 24),
          _About(),
        ],
      ),
    );
  }
}

class _RealtimeStatus extends StatelessWidget {
  const _RealtimeStatus();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final connected = app.realtimeConnected;
    return Card(
      child: ListTile(
        leading: Icon(
          connected ? Icons.wifi_tethering : Icons.cloud_off,
          color: connected ? AppTheme.safe : AppTheme.danger,
        ),
        title: Text(
          connected ? 'Live connection active' : 'Trying to connect…',
        ),
        subtitle: Text(
          connected
              ? 'Receiving alerts in real time.'
              : 'Check your internet connection.',
        ),
        trailing: connected
            ? const Icon(Icons.check_circle, color: AppTheme.safe)
            : const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
      ),
    );
  }
}

class _LocationSection extends StatelessWidget {
  const _LocationSection();

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocationController>();
    final app = context.read<AppController>();
    final manual = loc.isManualMode;
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              manual ? Icons.place_outlined : Icons.my_location,
              color: manual ? AppTheme.info : AppTheme.safe,
            ),
            title: Text(
              'Location',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              manual ? loc.locationLabel : 'Live GPS location',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LocationPickerScreen()),
            ),
          ),
          if (!manual) ...[
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.gps_fixed, color: AppTheme.primary),
              title: const Text('Grant GPS access'),
              subtitle: Text(
                loc.hasPermission
                    ? 'Location permission granted'
                    : loc.permissionDeniedForever
                        ? 'Permission blocked — open app settings'
                        : 'Needed for live (auto-updating) location',
              ),
              trailing: loc.hasPermission
                  ? const Icon(Icons.check_circle, color: AppTheme.safe)
                  : null,
              onTap: () async {
                if (loc.permissionDeniedForever) {
                  await app.openAppSettings();
                } else {
                  await app.requestGpsPermission();
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _SafetySection extends StatelessWidget {
  const _SafetySection();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppController>().settings;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ListTile(
              leading: Icon(Icons.security),
              title: Text(
                'Personal safety',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: settings.alertRadiusKm.clamp(5, 200),
                    min: 5,
                    max: 200,
                    divisions: 39,
                    label: '${settings.alertRadiusKm.toStringAsFixed(0)} km',
                    onChanged: (v) =>
                        _save(context, settings.copyWith(alertRadiusKm: v)),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${settings.alertRadiusKm.toStringAsFixed(0)} km',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(left: 16, bottom: 8, top: 4),
              child: Text(
                'Alert radius',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: Text(
                'Focused disaster types',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final t in DisasterType.values)
                    FilterChip(
                      label: Text(t.label),
                      selected: settings.isTypeSelected(t.id),
                      avatar: Icon(
                        AppTheme.typeIcon(t),
                        size: 16,
                        color: settings.isTypeSelected(t.id)
                            ? AppTheme.typeColor(t)
                            : null,
                      ),
                      onSelected: (v) {
                        final next = {...settings.selectedDisasterTypes};
                        if (v) {
                          next.add(t.id);
                        } else {
                          next.remove(t.id);
                        }
                        _save(
                          context,
                          settings.copyWith(selectedDisasterTypes: next),
                        );
                      },
                    ),
                ],
              ),
            ),
            SwitchListTile(
              value: settings.simulatorEnabled,
              title: const Text('Enable dev simulator'),
              subtitle: const Text('Inject test alerts (dev builds)'),
              onChanged: (v) =>
                  _save(context, settings.copyWith(simulatorEnabled: v)),
            ),
          ],
        ),
      ),
    );
  }

  void _save(BuildContext context, AppSettings next) {
    context.read<AppController>().updateSettings(next);
  }
}

class _NotificationsSection extends StatelessWidget {
  const _NotificationsSection();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppController>().settings;
    return Card(
      child: Column(
        children: [
          const ListTile(
            leading: Icon(Icons.notifications_active_outlined),
            title: Text(
              'Notifications',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text('How disaster alerts reach you'),
          ),
          SwitchListTile(
            value: settings.notificationsEnabled,
            title: const Text('Show alert notifications'),
            onChanged: (v) async {
              final controller = context.read<AppController>();
              if (v) await controller.requestNotificationPermission();
              await controller.updateSettings(
                settings.copyWith(notificationsEnabled: v),
              );
            },
          ),
          SwitchListTile(
            value: settings.soundEnabled,
            title: const Text('Sound'),
            onChanged: (v) => context.read<AppController>().updateSettings(
              settings.copyWith(soundEnabled: v),
            ),
          ),
          SwitchListTile(
            value: settings.vibrationEnabled,
            title: const Text('Vibration'),
            onChanged: (v) => context.read<AppController>().updateSettings(
              settings.copyWith(vibrationEnabled: v),
            ),
          ),
          SwitchListTile(
            value: settings.pushRemoteEnabled,
            title: const Text('Remote push (FCM)'),
            subtitle: const Text(
              'Server pushes when realtime socket is closed',
            ),
            onChanged: (v) => context.read<AppController>().updateSettings(
              settings.copyWith(pushRemoteEnabled: v),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeSection extends StatelessWidget {
  const _ThemeSection();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppController>().settings;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.brightness_6_outlined),
        title: const Text('Theme'),
        trailing: SegmentedButton<ThemeMode>(
          segments: const [
            ButtonSegment(
              value: ThemeMode.light,
              label: Text('Light'),
              icon: Icon(Icons.light_mode),
            ),
            ButtonSegment(
              value: ThemeMode.dark,
              label: Text('Dark'),
              icon: Icon(Icons.dark_mode),
            ),
            ButtonSegment(
              value: ThemeMode.system,
              label: Text('Auto'),
              icon: Icon(Icons.auto_awesome),
            ),
          ],
          selected: {settings.themeMode},
          onSelectionChanged: (s) => context
              .read<AppController>()
              .updateSettings(settings.copyWith(themeMode: s.first)),
        ),
      ),
    );
  }
}

class _MoreLinks extends StatelessWidget {
  const _MoreLinks();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.people_outline),
            title: const Text('Emergency contacts'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _push(context, const ContactsScreen()),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.apartment_outlined),
            title: const Text('Safe places & shelters'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _push(context, const SheltersScreen()),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Alert history'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _push(context, const HistoryScreen()),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: const Text('Survival Guide'),
            subtitle: const Text('What to do before, during and after each hazard'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _push(context, const SurvivalGuideScreen()),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.wb_sunny_outlined),
            title: const Text('Weather'),
            subtitle: const Text('Current conditions and forecast for your location'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _push(context, const WeatherScreen()),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.sensors_outlined),
            title: const Text('Recent Earthquakes'),
            subtitle: const Text('Filter live alerts to earthquake events'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _push(
              context,
              const LiveAlertsScreen(
                initialSection: 'recent',
                initialType: DisasterType.earthquake,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

class _SimulatorSection extends StatelessWidget {
  const _SimulatorSection();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final deps = context.read<AppDependencies>();
    final enabled = app.settings.simulatorEnabled;
    if (!enabled) return const SizedBox.shrink();

    return Card(
      color: AppTheme.warningA.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.science_outlined, color: AppTheme.warningA),
                const SizedBox(width: 8),
                const Text(
                  'Dev simulator',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 6),
                Text(
                  '(${app.settings.simulatorEnabled ? 'on' : 'off'})',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Generates synthetic alerts around 21.17, 72.83 that flow through the same pipeline',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => deps.simulator.simulateBurst(count: 4),
                    icon: const Icon(Icons.thunderstorm_outlined, size: 16),
                    label: const Text('Burst'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: deps.simulator.startAuto,
                    child: const Text('Auto every 45s'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: deps.simulator.stopAuto,
                    child: const Text('Stop'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => deps.simulator.simulateCritical(),
                    icon: const Icon(Icons.warning_amber_rounded, size: 16),
                    label: const Text('Critical'),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => deps.simulator.clearSimulatorData(),
                    icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                    label: const Text('Clear sim data'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _About extends StatelessWidget {
  const _About();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Disaster Alert v1.0.0',
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Text(
          'Offline-first real-time disaster alerting',
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: Colors.grey),
        ),
      ],
    );
  }
}
