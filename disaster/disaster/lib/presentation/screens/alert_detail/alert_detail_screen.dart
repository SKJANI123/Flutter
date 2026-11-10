import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:disaster/core/utils/geo_distance.dart';
import 'package:disaster/core/utils/launchers.dart';
import 'package:disaster/domain/entities/disaster.dart';
import 'package:disaster/domain/enums/alert_level.dart';
import 'package:disaster/domain/enums/disaster_status.dart';
import 'package:disaster/domain/value_objects/coordinates.dart';
import 'package:disaster/presentation/theme/app_theme.dart';
import 'package:disaster/presentation/widgets/common.dart';

/// Full details of one disaster alert with actions.
class AlertDetailScreen extends StatelessWidget {
  const AlertDetailScreen({
    super.key,
    required this.disaster,
    this.userLocation,
  });

  final Disaster disaster;
  final Coordinates? userLocation;

  @override
  Widget build(BuildContext context) {
    final distance = userLocation == null
        ? null
        : GeoDistance.haversineKm(userLocation!, disaster.coordinates);
    final level = distance == null
        ? AlertLevel.safe
        : disaster.levelForDistance(distance);
    final color = AppTheme.forLevel(level);

    return Scaffold(
      appBar: AppBar(title: Text(disaster.type.label)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Header(
            disaster: disaster,
            level: level,
            color: color,
            distance: distance,
          ),
          const SizedBox(height: 16),
          _InfoGrid(disaster: disaster),
          const SizedBox(height: 16),
          _Description(disaster: disaster),
          if (disaster.area != null) ...[
            const SizedBox(height: 16),
            _AreaCard(area: disaster.area!),
          ],
          if (disaster.externalUrl != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: disaster.externalUrl == null
                  ? null
                  : () =>
                        EmergencyLaunchers.openExternal(disaster.externalUrl!),
              icon: const Icon(Icons.open_in_browser),
              label: const Text('Official source'),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.safe),
                  onPressed: () =>
                      EmergencyLaunchers.openDirections(disaster.coordinates),
                  icon: const Icon(Icons.directions),
                  label: const Text('Navigate'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => EmergencyLaunchers.callEmergency(),
                  icon: const Icon(Icons.local_phone),
                  label: const Text('Call help'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Safety Instructions',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          _SafetyGuidance(instructions: disaster.instructions),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.disaster,
    required this.level,
    required this.color,
    required this.distance,
  });
  final Disaster disaster;
  final AlertLevel level;
  final Color color;
  final double? distance;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.7)]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DisasterTypeIcon(type: disaster.type, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      disaster.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${disaster.severity.name.toUpperCase()} SEVERITY',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'YOUR LEVEL',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    level.label.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'DISTANCE',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    distance == null
                        ? 'n/a'
                        : '${distance!.toStringAsFixed(1)} km',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.disaster});
  final Disaster disaster;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d, HH:mm');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _InfoRow(
              icon: Icons.place,
              label: 'Location',
              value:
                  '${disaster.coordinates.latitude.toStringAsFixed(4)}, ${disaster.coordinates.longitude.toStringAsFixed(4)}',
            ),
            if (disaster.area != null) ...[
              const Divider(),
              _InfoRow(
                icon: Icons.map_outlined,
                label: 'Area',
                value: disaster.area!,
              ),
            ],
            const Divider(),
            _InfoRow(
              icon: Icons.radar,
              label: 'Affected radius',
              value: '${disaster.affectedRadiusKm.toStringAsFixed(1)} km',
            ),
            if (disaster.magnitude != null) ...[
              const Divider(),
              _InfoRow(
                icon: Icons.speed,
                label: 'Magnitude',
                value: '${disaster.magnitude}',
              ),
            ],
            const Divider(),
            _InfoRow(
              icon: Icons.event,
              label: 'Occurred',
              value: disaster.occurredAt == null
                  ? 'unknown'
                  : fmt.format(disaster.occurredAt!),
            ),
            if (disaster.expiresAt != null) ...[
              const Divider(),
              _InfoRow(
                icon: Icons.timer_outlined,
                label: 'Valid until',
                value: fmt.format(disaster.expiresAt!),
              ),
            ],
            const Divider(),
            _InfoRow(
              icon: Icons.schedule,
              label: 'Status',
              value: disaster.status == DisasterStatus.resolved
                  ? 'Resolved'
                  : disaster.status.name.toUpperCase(),
            ),
            const Divider(),
            _InfoRow(
              icon: Icons.data_object,
              label: 'Source',
              value: disaster.source ?? disaster.provider.name.toUpperCase(),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _Description extends StatelessWidget {
  const _Description({required this.disaster});
  final Disaster disaster;

  @override
  Widget build(BuildContext context) {
    if (disaster.description == null) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          disaster.description!,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

class _AreaCard extends StatelessWidget {
  const _AreaCard({required this.area});
  final String area;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.map_outlined, color: AppTheme.info),
        title: const Text('Affected area'),
        subtitle: Text(area),
      ),
    );
  }
}

class _SafetyGuidance extends StatelessWidget {
  const _SafetyGuidance({this.instructions});
  final String? instructions;

  @override
  Widget build(BuildContext context) {
    final items = instructions != null && instructions!.trim().isNotEmpty
        ? instructions!
              .split('\n')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .map((s) => (Icons.chevron_right, s))
              .toList()
        : const [
            (Icons.arrow_upward, 'Move to higher ground if flooding is possible.'),
            (Icons.volunteer_activism, 'Follow instructions from local authorities.'),
            (Icons.phonelink_ring, 'Keep your phone charged and notifications on.'),
            (Icons.people_outline, 'Check on neighbours, especially the elderly.'),
          ];
    return Card(
      child: Column(
        children: [
          for (final (icon, text) in items)
            ListTile(
              leading: Icon(icon, color: AppTheme.primary),
              title: Text(text),
            ),
        ],
      ),
    );
  }
}
