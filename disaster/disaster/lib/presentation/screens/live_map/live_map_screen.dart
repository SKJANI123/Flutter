import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import 'package:disaster/core/utils/geo_distance.dart';
import 'package:disaster/domain/entities/disaster.dart';
import 'package:disaster/domain/entities/shelter.dart';
import 'package:disaster/domain/enums/alert_level.dart';
import 'package:disaster/domain/enums/disaster_type.dart';
import 'package:disaster/domain/value_objects/coordinates.dart';
import 'package:disaster/presentation/providers/location_controller.dart';
import 'package:disaster/presentation/providers/map_controller.dart';
import 'package:disaster/presentation/screens/alert_detail/alert_detail_screen.dart';
import 'package:disaster/presentation/screens/shelters/shelter_detail_screen.dart';
import 'package:disaster/presentation/theme/app_theme.dart';

/// Live map with the user (GPS or manual place), active disaster events
/// (severity-colored markers + affected-radius circles) and nearby shelters.
class LiveMapScreen extends StatefulWidget {
  const LiveMapScreen({super.key});

  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen> {
  final fm.MapController _mapController = fm.MapController();

  /// Empty means "show all types"; non-empty narrows the rendered markers and
  /// circles (and the disaster list) to the selected disaster types.
  final Set<DisasterType> _filterTypes = {};

  void _toggleType(DisasterType type) {
    setState(() {
      if (!_filterTypes.add(type)) {
        _filterTypes.remove(type);
      }
    });
  }

  void _clearTypes() {
    setState(() => _filterTypes.clear());
  }

  List<Disaster> _visible() {
    final disasters = context.read<MapController>().disasters;
    if (_filterTypes.isEmpty) return disasters;
    return disasters.where((d) => _filterTypes.contains(d.type)).toList();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _recenter(LatLng? target) {
    if (target == null) return;
    _mapController.move(target, 12);
  }

  /// Recenters on a specific disaster and surfaces its details sheet, same as
  /// tapping its marker.
  void _focusAndShow(Disaster d) {
    final ctrl = context.read<MapController>();
    if (!mounted) return;
    _mapController.move(
      LatLng(d.coordinates.latitude, d.coordinates.longitude),
      11,
    );
    final level = _levelFor(d, ctrl.userLocation);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => _DisasterSheet(
        disaster: d,
        level: level,
        color: AppTheme.forLevel(level),
        userLocation: ctrl.userLocation,
      ),
    );
  }

  void _openDisasterList() {
    final ctrl = context.read<MapController>();
    final user = ctrl.userLocation;
    final visible = _visible();
    if (visible.isEmpty) return;
    // Sorted by distance from the user so the closest is listed first.
    final sorted = [...visible]..sort((a, b) {
        final da = user == null
            ? 0.0
            : GeoDistance.haversineKm(user, a.coordinates);
        final db = user == null
            ? 0.0
            : GeoDistance.haversineKm(user, b.coordinates);
        return da.compareTo(db);
      });
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => _DisasterListSheet(
        disasters: sorted,
        userLocation: user,
        onSelected: (d) {
          Navigator.of(ctx).pop();
          _focusAndShow(d);
        },
      ),
    );
  }

  AlertLevel _levelFor(Disaster d, Coordinates? user) {
    if (user == null) {
      return AlertLevel.values.firstWhere(
        (l) => l.weight == d.severity.weight.clamp(0, AlertLevel.critical.weight),
      );
    }
    return d.levelForDistance(GeoDistance.haversineKm(user, d.coordinates));
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<MapController>();
    final place = context.watch<LocationController>();
    final user = ctrl.userLocation;
    final disasters = _visible();
    final shelters = ctrl.shelters;

    final center = user == null
        ? const LatLng(21.1702401, 72.831062)
        : LatLng(user.latitude, user.longitude);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.format_list_bulleted),
            tooltip: 'Disasters on map',
            onPressed: disasters.isEmpty ? null : _openDisasterList,
          ),
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Recenter',
            onPressed: () => _recenter(center),
          ),
        ],
      ),
      body: Stack(
        children: [
          fm.FlutterMap(
            mapController: _mapController,
            options: fm.MapOptions(
              initialCenter: center,
              initialZoom: 10,
              interactionOptions: const fm.InteractionOptions(
                flags: fm.InteractiveFlag.all & ~fm.InteractiveFlag.rotate,
              ),
            ),
            children: [
              fm.TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.disaster_alert',
              ),
              if (ctrl.showShelters && shelters.isNotEmpty)
                fm.MarkerLayer(
                  markers: [
                    for (final s in shelters)
                      fm.Marker(
                        point: LatLng(
                          s.coordinates.latitude,
                          s.coordinates.longitude,
                        ),
                        width: 36,
                        height: 36,
                        child: _ShelterMarker(shelter: s),
                      ),
                  ],
                ),
              if (disasters.isNotEmpty)
                fm.CircleLayer(
                  circles: [
                    for (final d in disasters)
                      fm.CircleMarker(
                        point: LatLng(
                          d.coordinates.latitude,
                          d.coordinates.longitude,
                        ),
                        radius: d.affectedRadiusKm * 1000,
                        useRadiusInMeter: true,
                        color: AppTheme.forLevel(_levelFor(d, user))
                            .withValues(alpha: 0.08),
                        borderColor: AppTheme.forLevel(_levelFor(d, user))
                            .withValues(alpha: 0.45),
                        borderStrokeWidth: 1.5,
                      ),
                  ],
                ),
              if (disasters.isNotEmpty)
                fm.MarkerLayer(
                  markers: [
                    for (final d in disasters)
                      fm.Marker(
                        point: LatLng(
                          d.coordinates.latitude,
                          d.coordinates.longitude,
                        ),
                        width: 44,
                        height: 44,
                        child: _DisasterMarker(
                          disaster: d,
                          level: _levelFor(d, user),
                          userLocation: user,
                        ),
                      ),
                  ],
                ),
              if (user != null)
                fm.MarkerLayer(
                  markers: [
                    fm.Marker(
                      point: LatLng(user.latitude, user.longitude),
                      width: 44,
                      height: 44,
                      child: _UserMarker(
                        manual: place.isManualMode,
                        label: place.locationLabel,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (user != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 20,
              child: _UserChip(manual: place.isManualMode, label: place.locationLabel),
            ),
          Positioned(
            left: 8,
            right: 8,
            top: 8,
            child: _TypeFilterChips(
              selected: _filterTypes,
              onToggle: _toggleType,
              onClear: _clearTypes,
            ),
          ),
          Positioned(
            left: 12,
            bottom: user == null ? 20 : 78,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Legend(
                  icon: place.isManualMode
                      ? Icons.place
                      : Icons.my_location,
                  color: AppTheme.info,
                  label: 'You',
                ),
                _Legend(
                  icon: Icons.warning_amber_rounded,
                  color: AppTheme.forLevel(AlertLevel.critical),
                  label: 'Disaster · severity',
                ),
                _Legend(
                  icon: Icons.apartment,
                  color: AppTheme.safe,
                  label: 'Shelter',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UserChip extends StatelessWidget {
  const _UserChip({required this.manual, required this.label});
  final bool manual;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              manual ? Icons.place : Icons.my_location,
              size: 15,
              color: AppTheme.info,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.icon, required this.color, required this.label});
  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _DisasterMarker extends StatelessWidget {
  const _DisasterMarker({
    required this.disaster,
    required this.level,
    required this.userLocation,
  });
  final Disaster disaster;
  final AlertLevel level;
  final Coordinates? userLocation;

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.forLevel(level);
    return GestureDetector(
      onTap: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (_) => _DisasterSheet(
          disaster: disaster,
          level: level,
          color: color,
          userLocation: userLocation,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 3),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
        ),
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(
            AppTheme.typeIcon(disaster.type),
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _DisasterSheet extends StatelessWidget {
  const _DisasterSheet({
    required this.disaster,
    required this.level,
    required this.color,
    required this.userLocation,
  });
  final Disaster disaster;
  final AlertLevel level;
  final Color color;
  final Coordinates? userLocation;

  @override
  Widget build(BuildContext context) {
    final distance = userLocation == null
        ? null
        : GeoDistance.haversineKm(userLocation!, disaster.coordinates);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(AppTheme.typeIcon(disaster.type), color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  disaster.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            disaster.description ?? '',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            [
              '${disaster.affectedRadiusKm.toStringAsFixed(1)} km radius',
              '${disaster.severity.name} severity',
              if (distance != null) '${distance.toStringAsFixed(1)} km away',
            ].join(' · '),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            level.label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 13,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('View details'),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AlertDetailScreen(
                      disaster: disaster,
                      userLocation: userLocation,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _UserMarker extends StatelessWidget {
  const _UserMarker({required this.manual, required this.label});
  final bool manual;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppTheme.info,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
      ),
      child: Icon(
        manual ? Icons.place : Icons.my_location,
        color: Colors.white,
        size: 22,
        semanticLabel: label,
      ),
    );
  }
}

class _ShelterMarker extends StatelessWidget {
  const _ShelterMarker({required this.shelter});
  final Shelter shelter;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ShelterDetailScreen(shelter: shelter),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppTheme.safe,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
        ),
        child: const Icon(Icons.apartment, color: Colors.white, size: 18),
      ),
    );
  }
}

/// Horizontally scrollable disaster-type chips overlaid on the map. Selecting
/// a type narrows the markers/circles (and the disaster list) to that hazard.
class _TypeFilterChips extends StatelessWidget {
  const _TypeFilterChips({
    required this.selected,
    required this.onToggle,
    required this.onClear,
  });

  final Set<DisasterType> selected;
  final ValueChanged<DisasterType> onToggle;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('All'),
            avatar: const Icon(Icons.filter_alt_off_outlined, size: 16),
            selected: selected.isEmpty,
            onSelected: (_) => onClear(),
          ),
          const SizedBox(width: 6),
          for (final type in DisasterType.values) ...[
            ChoiceChip(
              avatar: Icon(AppTheme.typeIcon(type), size: 14),
              label: Text(type.label),
              selected: selected.contains(type),
              onSelected: (_) => onToggle(type),
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

/// Bottom sheet listing the disasters currently represented on the map
/// (closest first). Picking one recenters the map and opens its details.
class _DisasterListSheet extends StatelessWidget {
  const _DisasterListSheet({
    required this.disasters,
    required this.userLocation,
    required this.onSelected,
  });

  final List<Disaster> disasters;
  final Coordinates? userLocation;
  final ValueChanged<Disaster> onSelected;

  @override
  Widget build(BuildContext context) {
    final count = disasters.length;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Disasters on map ($count)',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap one to jump to it and view details.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: disasters.length,
                itemBuilder: (context, i) {
                  final d = disasters[i];
                  final distance = userLocation == null
                      ? null
                      : GeoDistance.haversineKm(userLocation!, d.coordinates);
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.typeColor(
                        d.type,
                      ).withValues(alpha: 0.15),
                      child: Icon(
                        AppTheme.typeIcon(d.type),
                        color: AppTheme.typeColor(d.type),
                        size: 20,
                      ),
                    ),
                    title: Text(d.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      [
                        d.type.label,
                        d.severity.name,
                        if (distance != null) '${distance.toStringAsFixed(1)} km',
                      ].join(' · '),
                    ),
                    trailing: const Icon(Icons.center_focus_strong, size: 20),
                    onTap: () => onSelected(d),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
