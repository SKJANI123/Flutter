import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:disaster/domain/enums/disaster_type.dart';
import 'package:disaster/presentation/providers/history_controller.dart';
import 'package:disaster/presentation/screens/alert_detail/alert_detail_screen.dart';
import 'package:disaster/presentation/theme/app_theme.dart';
import 'package:disaster/presentation/widgets/common.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<HistoryController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Alert History')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: TextField(
              onChanged: ctrl.setQuery,
              decoration: InputDecoration(
                hintText: 'Search alerts…',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final t in DisasterType.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(t.label),
                      selected: ctrl.types.contains(t),
                      onSelected: (_) => ctrl.toggleType(t),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(child: _body(context, ctrl)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, HistoryController ctrl) {
    if (ctrl.loading) return const Center(child: CircularProgressIndicator());
    if (ctrl.error != null) {
      return const EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load history',
      );
    }
    if (ctrl.entries.isEmpty) {
      return const EmptyState(
        icon: Icons.history,
        title: 'No alert history yet',
        subtitle: 'Alerts triggered around you will appear here.',
      );
    }
    return RefreshIndicator(
      onRefresh: () => ctrl.load(),
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: ctrl.entries.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, i) => _HistoryRow(entry: ctrl.entries[i]),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry});
  final dynamic entry;

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.forLevel(entry.newLevel);
    return Card(
      child: ListTile(
        leading: entry.disaster == null
            ? CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(Icons.crisis_alert, color: color),
              )
            : DisasterTypeIcon(type: entry.disaster!.type, size: 44),
        title: Text(
          entry.disaster?.title ?? 'Alert #${entry.disasterId}',
          style: const TextStyle(fontWeight: FontWeight.w700),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            [
              'Triggered ${_fmt(entry.triggeredAt)}',
              if (entry.distanceKm != null)
                '${entry.distanceKm!.toStringAsFixed(1)} km away',
              if (entry.previousLevel != null)
                'was ${entry.previousLevel!.label}',
            ].join(' · '),
            style: const TextStyle(fontSize: 12),
          ),
        ),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              entry.newLevel.label.toUpperCase(),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _notifStatus(entry.notificationStatus),
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
        onTap: entry.disaster == null
            ? null
            : () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AlertDetailScreen(disaster: entry.disaster!),
                ),
              ),
      ),
    );
  }

  String _fmt(DateTime? d) {
    if (d == null) return 'unknown';
    final local = d.toLocal();
    return '${local.month.toString().padLeft(2, '0')}/${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  String _notifStatus(dynamic status) => switch (status?.code as String?) {
    'sent' => 'notified',
    'suppressed' => 'silenced',
    'scheduled' => 'scheduled',
    _ => '',
  };
}
