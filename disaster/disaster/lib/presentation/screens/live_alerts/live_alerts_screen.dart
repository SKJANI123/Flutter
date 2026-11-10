import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:disaster/core/network/connectivity_service.dart';
import 'package:disaster/domain/enums/disaster_type.dart';
import 'package:disaster/domain/enums/severity.dart';
import 'package:disaster/presentation/providers/alerts_controller.dart';
import 'package:disaster/presentation/screens/alert_detail/alert_detail_screen.dart';
import 'package:disaster/presentation/theme/app_theme.dart';
import 'package:disaster/presentation/widgets/common.dart';

class LiveAlertsScreen extends StatefulWidget {
  const LiveAlertsScreen({super.key, this.initialSection, this.initialType});

  /// When set, opens the screen scoped to a section (e.g. from a home "View
  /// all" shortcut).
  final String? initialSection;

  /// When set, opens the screen filtered to one disaster type (e.g. a "Recent
  /// Earthquakes" shortcut).
  final DisasterType? initialType;

  @override
  State<LiveAlertsScreen> createState() => _LiveAlertsScreenState();
}

class _LiveAlertsScreenState extends State<LiveAlertsScreen> {
  bool _appliedInitial = false;

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<AlertsController>();
    if (!_appliedInitial) {
      _appliedInitial = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.initialSection != null) {
          ctrl.setSection(AlertsController.sectionFrom(widget.initialSection!));
        }
        if (mounted && widget.initialType != null && !ctrl.hasTypeFilter) {
          ctrl.toggleTypeFilter(widget.initialType!);
        }
      });
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Alerts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ctrl.refresh(),
          ),
        ],
      ),
      body: Column(
        children: [
          OfflineBanner(
            visible: context.watch<ConnectivityService>().isOnline == false,
          ),
          _SectionBar(ctrl: ctrl),
          _FilterBar(ctrl: ctrl),
          Expanded(child: _buildBody(context, ctrl)),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, AlertsController ctrl) {
    if (ctrl.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (ctrl.error != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load alerts',
        subtitle: 'Pull to retry.',
      );
    }
    if (ctrl.items.isEmpty) {
      return const EmptyState(
        icon: Icons.shield_outlined,
        title: 'No active alerts',
        subtitle: 'You are all clear. We will alert you instantly if anything changes.',
      );
    }
    return RefreshIndicator(
      onRefresh: () => ctrl.refresh(),
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: ctrl.items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) => _AlertRow(item: ctrl.items[i]),
      ),
    );
  }
}

/// All / Critical / Nearby / Recent sections.
class _SectionBar extends StatelessWidget {
  const _SectionBar({required this.ctrl});
  final AlertsController ctrl;

  @override
  Widget build(BuildContext context) {
    final sections = <(String, String)>[
      (AlertsController.sectionAll, 'All'),
      (AlertsController.sectionCritical, 'Critical'),
      (AlertsController.sectionNearby, 'Nearby'),
      (AlertsController.sectionRecent, 'Recent'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final s in sections) ...[
              ChoiceChip(
                label: Text(s.$2),
                selected: ctrl.section == s.$1,
                onSelected: (_) => ctrl.setSection(s.$1),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.ctrl});
  final AlertsController ctrl;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  avatar: const Icon(Icons.cloud_outlined, size: 16),
                  label: const Text('All'),
                  selected: ctrl.providerFilter == 'all',
                  onSelected: (_) => ctrl.setProviderFilter('all'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  avatar: const Icon(Icons.public, size: 16),
                  label: const Text('Official'),
                  selected: ctrl.showingServer,
                  onSelected: (_) => ctrl.setProviderFilter('server'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  avatar: const Icon(Icons.science_outlined, size: 16),
                  label: const Text('Simulator'),
                  selected: ctrl.showingSimulator,
                  onSelected: (_) => ctrl.setProviderFilter('simulator'),
                ),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: Icon(
                    ctrl.hasFilters
                        ? Icons.filter_alt
                        : Icons.filter_alt_outlined,
                    size: 16,
                    color: ctrl.hasFilters ? AppTheme.primary : null,
                  ),
                  label: Text(ctrl.hasFilters ? 'Filters' : 'Filter'),
                  onPressed: () => _openFilters(context, ctrl),
                ),
                if (ctrl.hasFilters) ...[
                  const SizedBox(width: 4),
                  ActionChip(
                    label: const Text('Clear'),
                    onPressed: ctrl.clearFilters,
                  ),
                ],
              ],
            ),
          ),
          if (ctrl.hasTypeFilter) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Filtered: ${ctrl.items.length} shown',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                TextButton(
                  onPressed: ctrl.clearTypeFilter,
                  child: const Text('Clear types'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _openFilters(BuildContext context, AlertsController ctrl) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => _FiltersSheet(ctrl: ctrl),
    );
  }
}

class _FiltersSheet extends StatefulWidget {
  const _FiltersSheet({required this.ctrl});
  final AlertsController ctrl;

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  late Severity? _severity;
  late double _maxKm;
  late DateTime? _from;

  bool get _fromActive => _from != null;

  @override
  void initState() {
    super.initState();
    _severity = widget.ctrl.severityFilter;
    _maxKm = widget.ctrl.maxDistanceKm ?? 100;
    _from = widget.ctrl.dateFilter;
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.ctrl;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filters',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text('Severity', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (final s in Severity.values)
                ChoiceChip(
                  label: Text(s.name),
                  selected: _severity == s,
                  onSelected: (_) => setState(() => _severity = s),
                ),
              ChoiceChip(
                label: const Text('Any'),
                selected: _severity == null,
                onSelected: (_) => setState(() => _severity = null),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Max distance', style: Theme.of(context).textTheme.titleSmall),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _maxKm,
                  min: 5,
                  max: 500,
                  divisions: 99,
                  label: '${_maxKm.round()} km',
                  onChanged: (v) => setState(() => _maxKm = v),
                ),
              ),
              Text('${_maxKm.round()} km',
                  style: TextStyle(color: scheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 8),
          Text('Updated after', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Any time'),
                selected: !_fromActive,
                onSelected: (_) => setState(() => _from = null),
              ),
              ChoiceChip(
                label: const Text('Last 24h'),
                selected:
                    _from != null &&
                    _from!.isAfter(DateTime.now().subtract(const Duration(hours: 24))) &&
                    !_from!.isAfter(DateTime.now().subtract(const Duration(minutes: 1))),
                onSelected: (_) => setState(
                  () => _from = DateTime.now().subtract(const Duration(hours: 24)),
                ),
              ),
              ChoiceChip(
                label: const Text('Last 7 days'),
                selected: _fromActive &&
                    _from!.isAfter(DateTime.now().subtract(const Duration(days: 7))) &&
                    !_from!.isAfter(DateTime.now().subtract(const Duration(hours: 23))),
                onSelected: (_) => setState(
                  () => _from = DateTime.now().subtract(const Duration(days: 7)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              OutlinedButton(
                onPressed: () {
                  ctrl.setSeverityFilter(null);
                  ctrl.setMaxDistanceKm(null);
                  ctrl.setDateFilter(null);
                  Navigator.of(context).pop();
                },
                child: const Text('Clear'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () {
                  ctrl.setSeverityFilter(_severity);
                  ctrl.setMaxDistanceKm(_maxKm < 500 ? _maxKm : null);
                  ctrl.setDateFilter(_from);
                  Navigator.of(context).pop();
                },
                child: const Text('Apply'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({required this.item});
  final dynamic item;

  @override
  Widget build(BuildContext context) {
    final levelColor = AppTheme.forLevel(item.level);
    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: levelColor.withValues(alpha: 0.5), width: 1.2),
      ),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AlertDetailScreen(disaster: item.disaster),
          ),
        ),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              DisasterTypeIcon(type: item.disaster.type, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.disaster.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.disaster.description,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.place,
                          size: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          item.distanceKm == null
                              ? 'distance unknown'
                              : '${item.distanceKm!.toStringAsFixed(1)} km',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const Spacer(),
                        Text(
                          item.level.label.toUpperCase(),
                          style: TextStyle(
                            color: levelColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
