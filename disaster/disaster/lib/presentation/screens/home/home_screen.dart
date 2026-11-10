import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:disaster/core/utils/launchers.dart';
import 'package:disaster/data/sources/source_health.dart';
import 'package:disaster/domain/enums/alert_level.dart';
import 'package:disaster/domain/enums/disaster_type.dart';
import 'package:disaster/presentation/providers/alerts_controller.dart';
import 'package:disaster/presentation/providers/app_dependencies.dart';
import 'package:disaster/presentation/providers/home_controller.dart';
import 'package:disaster/presentation/screens/alert_detail/alert_detail_screen.dart';
import 'package:disaster/presentation/screens/contacts/contacts_screen.dart';
import 'package:disaster/presentation/screens/guide/survival_guide_screen.dart';
import 'package:disaster/presentation/screens/history/history_screen.dart';
import 'package:disaster/presentation/screens/live_alerts/live_alerts_screen.dart';
import 'package:disaster/presentation/screens/live_map/live_map_screen.dart';
import 'package:disaster/presentation/screens/settings/settings_screen.dart';
import 'package:disaster/presentation/screens/shelters/shelters_screen.dart';
import 'package:disaster/presentation/screens/sos/sos_screen.dart';
import 'package:disaster/presentation/screens/weather/weather_screen.dart';
import 'package:disaster/presentation/theme/app_theme.dart';
import 'package:disaster/presentation/widgets/common.dart';
import 'package:disaster/presentation/widgets/location_header.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<HomeController>();
    final alerts = context.watch<AlertsController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Disaster Alert'),
        actions: [
          IconButton(
            icon: const Icon(Icons.crisis_alert),
            color: AppTheme.danger,
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const LiveMapScreen())),
          ),
        ],
      ),
      backgroundColor: isDark
          ? Theme.of(context).scaffoldBackgroundColor
          : Colors.grey.shade50,
      body: RefreshIndicator(
        onRefresh: () => context.read<HomeController>().refresh(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const LocationHeader(),
            const SizedBox(height: 14),
            _StatusHero(ctrl: ctrl),
            const SizedBox(height: 16),
            _Stats(ctrl: ctrl),
            const SizedBox(height: 20),
            Row(
              children: [
                Text(
                  'Quick actions',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const _QuickActions(),
            const SizedBox(height: 20),
            _AlertSection(
              title: 'Critical',
              icon: Icons.warning_amber_rounded,
              accent: AppTheme.forLevel(AlertLevel.critical),
              items: alerts.criticalItems,
              emptyText: 'No critical alerts right now.',
              sectionId: AlertsController.sectionCritical,
            ),
            const SizedBox(height: 16),
            _AlertSection(
              title: 'Nearby',
              icon: Icons.near_me,
              accent: AppTheme.warningA,
              items: alerts.nearbyItems,
              emptyText: ctrl.userLocation == null
                  ? 'Select a location to measure proximity.'
                  : 'Nothing within radius right now.',
              sectionId: AlertsController.sectionNearby,
            ),
            const SizedBox(height: 16),
            _AlertSection(
              title: 'Recent',
              icon: Icons.schedule,
              accent: AppTheme.info,
              items: alerts.recentItems,
              emptyText: 'No activity in the last 24 hours.',
              sectionId: AlertsController.sectionRecent,
            ),
            const SizedBox(height: 20),
            const _SourceStatusFooter(),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _StatusHero extends StatelessWidget {
  const _StatusHero({required this.ctrl});
  final HomeController ctrl;

  @override
  Widget build(BuildContext context) {
    final level = ctrl.worstLevel;
    final color = AppTheme.forLevel(level);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.75)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                level == AlertLevel.safe
                    ? Icons.shield_outlined
                    : Icons.warning_amber_rounded,
                color: level == AlertLevel.safe ? Colors.black54 : Colors.white,
                size: 32,
              ),
              const SizedBox(width: 10),
              Text(
                level.label.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Text(
                level == AlertLevel.safe ? 'IN SAFE ZONE' : 'MONITOR',
                style: TextStyle(
                  color: level == AlertLevel.safe
                      ? Colors.black54
                      : Colors.white.withValues(alpha: 0.9),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            ctrl.summaryText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            ctrl.userLocation == null
                ? 'GPS unavailable — alerts shown without radius'
                : 'Live on: ${ctrl.userLocation!.latitude.toStringAsFixed(4)}, ${ctrl.userLocation!.longitude.toStringAsFixed(4)}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.ctrl});
  final HomeController ctrl;

  @override
  Widget build(BuildContext context) {
    final active = ctrl.activeCount;
    return Row(
      children: [
        Expanded(
          child: StatCard(
            label: 'Active alerts',
            value: '$active',
            icon: Icons.crisis_alert,
            color: AppTheme.danger,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatCard(
            label: 'Near you',
            value:
                '${ctrl.cards.where((c) => c.level != AlertLevel.safe).length}',
            icon: Icons.near_me,
            color: AppTheme.warningA,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatCard(
            label: 'GPS',
            value: ctrl.userLocation == null ? 'off' : 'on',
            icon: Icons.my_location,
            color: AppTheme.safe,
          ),
        ),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      children: [
        _ActionTile(
          icon: Icons.sos,
          color: AppTheme.danger,
          label: 'SOS',
          onTap: () => _push(context, const SosScreen()),
        ),
        _ActionTile(
          icon: Icons.map_outlined,
          color: AppTheme.info,
          label: 'Map',
          onTap: () => _push(context, const LiveMapScreen()),
        ),
        _ActionTile(
          icon: Icons.crisis_alert_outlined,
          color: AppTheme.warningA,
          label: 'Alerts',
          onTap: () => _push(context, const LiveAlertsScreen()),
        ),
        _ActionTile(
          icon: Icons.people_outline,
          color: AppTheme.safe,
          label: 'Contacts',
          onTap: () => _push(context, const ContactsScreen()),
        ),
        _ActionTile(
          icon: Icons.apartment_outlined,
          color: AppTheme.primary,
          label: 'Shelters',
          onTap: () => _push(context, const SheltersScreen()),
        ),
        _ActionTile(
          icon: Icons.history,
          color: AppTheme.warningB,
          label: 'History',
          onTap: () => _push(context, const HistoryScreen()),
        ),
        _ActionTile(
          icon: Icons.settings_outlined,
          color: AppTheme.secondary,
          label: 'Settings',
          onTap: () => _push(context, const SettingsScreen()),
        ),
        _ActionTile(
          icon: Icons.wb_sunny_outlined,
          color: const Color(0xFFF9A825),
          label: 'Weather',
          onTap: () => _push(context, const WeatherScreen()),
        ),
        _ActionTile(
          icon: Icons.menu_book_outlined,
          color: AppTheme.primary,
          label: 'Guide',
          onTap: () => _push(context, const SurvivalGuideScreen()),
        ),
        _ActionTile(
          icon: Icons.sensors_outlined,
          color: AppTheme.warningB,
          label: 'Quakes',
          onTap: () => _push(
            context,
            const LiveAlertsScreen(
              initialSection: 'recent',
              initialType: DisasterType.earthquake,
            ),
          ),
        ),
        _ActionTile(
          icon: Icons.phonelink_ring_outlined,
          color: AppTheme.danger,
          label: 'Helpline',
          onTap: () => showEmergencyHelpline(context),
        ),
      ],
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  void showEmergencyHelpline(BuildContext context) {
    const numbers = <(String, String, IconData, Color)>[
      ('Universal Emergency', '112', Icons.emergency_outlined, AppTheme.danger),
      ('Police', '100', Icons.local_police_outlined, AppTheme.info),
      ('Fire', '101', Icons.local_fire_department_outlined, AppTheme.warningA),
      ('Ambulance', '102', Icons.local_hospital_outlined, AppTheme.safe),
      ('National Emergency (dial once)', '108', Icons.phonelink_ring_outlined,
          AppTheme.secondary),
    ];
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Emergency Helpline',
                style: Theme.of(
                  ctx,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'Numbers may differ by country. Tap to call.',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              for (final (label, number, icon, color) in numbers)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.15),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  title: Text(label),
                  subtitle: Text(
                    'Call $number → ',
                  ),
                  trailing: const Icon(Icons.call_outlined),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    EmergencyLaunchers.call(number);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThreatCard extends StatelessWidget {
  const _ThreatCard({required this.item});
  final DisasterListItem item;

  @override
  Widget build(BuildContext context) {
    final level = item.level;
    final color = AppTheme.forLevel(level);
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                AlertDetailScreen(disaster: item.disaster),
          ),
        ),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(
                AppTheme.typeIcon(item.disaster.type),
                color: color,
                size: 30,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.disaster.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.distanceKm == null
                          ? item.disaster.area ?? 'Distance unknown'
                          : '${item.distanceKm!.toStringAsFixed(1)} km away',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                item.disaster.severity.name.toUpperCase(),
                style: TextStyle(
                  color: AppTheme.severityColor(item.disaster.severity),
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One home section (Critical / Nearby / Recent) with a compact preview and a
/// "view all" shortcut into the alerts list.
class _AlertSection extends StatelessWidget {
  const _AlertSection({
    required this.title,
    required this.icon,
    required this.accent,
    required this.items,
    required this.emptyText,
    this.sectionId,
  });

  final String title;
  final IconData icon;
  final Color accent;
  final List<DisasterListItem> items;
  final String emptyText;

  /// When set, "View all" opens the alerts list scoped to this section.
  final String? sectionId;

  @override
  Widget build(BuildContext context) {
    final preview = items.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, color: accent, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            if (items.length > 3)
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => LiveAlertsScreen(
                      initialSection: sectionId,
                    ),
                  ),
                ),
                child: const Text('View all'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (preview.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Text(
              emptyText,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          for (final item in preview)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ThreatCard(item: item),
            ),
      ],
    );
  }
}

/// Shows which official feeds are live / unreachable, with a manual refresh.
class _SourceStatusFooter extends StatelessWidget {
  const _SourceStatusFooter();

  @override
  Widget build(BuildContext context) {
    final deps = context.read<AppDependencies>();
    return ListenableBuilder(
      listenable: deps.sourceHealth,
      builder: (context, _) {
        final entries = deps.sourceHealth.entries;
        if (entries.isEmpty) return const SizedBox.shrink();
        final ok = deps.sourceHealth.liveCount;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.hub_outlined, size: 18, color: AppTheme.info),
                  const SizedBox(width: 8),
                  Text(
                    'Alert sources  ($ok/${entries.length} online)',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 18),
                    tooltip: 'Refresh sources',
                    onPressed: () => deps.ingestion.refresh(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              for (final e in entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        e.state == SourceState.ok
                            ? Icons.check_circle
                            : Icons.error_outline,
                        size: 16,
                        color:
                            e.state == SourceState.ok
                                ? AppTheme.safe
                                : AppTheme.danger,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          e.name,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      Text(
                        e.state == SourceState.ok
                            ? e.lastSuccess == null
                                ? 'online'
                                : _ago(e.lastSuccess!)
                            : e.lastFailure == null
                                ? 'waiting'
                                : 'offline · $_ago(e.lastFailure!)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  static String _ago(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
