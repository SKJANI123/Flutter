import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:disaster/data/remote/api/geocoding_service.dart';
import 'package:disaster/domain/entities/location_record.dart';
import 'package:disaster/presentation/providers/app_controller.dart';
import 'package:disaster/presentation/providers/app_dependencies.dart';
import 'package:disaster/presentation/providers/location_controller.dart';
import 'package:disaster/presentation/theme/app_theme.dart';

/// Lets the user pick between live GPS and a saved / freshly-searched manual
/// place. Manual places are geocoded with the keyless Open-Meteo API so the
/// whole app works with no GPS permission.
class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final _searchController = TextEditingController();
  List<LocationRecord> _saved = [];
  List<GeocodeResult> _results = [];
  bool _searching = false;
  bool _picking = false;
  String? _searchError;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSaved() async {
    final deps = context.read<AppDependencies>();
    final saved = await deps.locations.getAll();
    if (mounted) setState(() => _saved = saved);
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty || _searching) return;
    final deps = context.read<AppDependencies>();
    setState(() {
      _searching = true;
      _searchError = null;
      _results = [];
    });
    try {
      final hits = await deps.geocoder.search(query);
      if (mounted) setState(() => _results = hits);
    } on Object catch (e) {
      if (mounted) setState(() => _searchError = 'Search failed: $e');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _saveAndSelect(GeocodeResult hit) async {
    if (_picking) return;
    setState(() => _picking = true);
    final deps = context.read<AppDependencies>();
    final app = context.read<AppController>();
    final record = _toRecord(hit);
    final nav = Navigator.of(context);
    await deps.locations.upsert(record);
    await app.selectManualLocation(record);
    await _loadSaved();
    if (mounted) {
      setState(() {
        _picking = false;
        _results = [];
        _searchController.clear();
      });
      nav.pop();
    }
  }

  LocationRecord _toRecord(GeocodeResult hit) {
    final idPart = [
      hit.coordinates.latitude.toStringAsFixed(4),
      hit.coordinates.longitude.toStringAsFixed(4),
      hit.name,
    ].join('|');
    return LocationRecord(
      id: 'manual_${idPart.hashCode}',
      label: hit.name,
      coordinates: hit.coordinates,
      mode: LocationMode.manual,
      city: hit.name,
      district: hit.district,
      state: hit.state,
      pinCode: hit.postcodes.isNotEmpty ? hit.postcodes.first : null,
      address: hit.country,
      isSelected: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocationController>();
    final app = context.read<AppController>();
    final gpsActive = loc.mode == LocationMode.gps;

    return Scaffold(
      appBar: AppBar(title: const Text('Location')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Alert distance & weather warnings are computed from the chosen '
            'reference point.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),

          // GPS option.
          _OptionTile(
            leading: Icon(Icons.my_location, color: AppTheme.primary),
            title: 'Use my GPS location',
            subtitle: 'Live coordinates (asks for permission)',
            selected: gpsActive,
            onTap: () async {
              final nav = Navigator.of(context);
              await app.useGps();
              if (mounted) nav.pop();
            },
          ),
          const Divider(height: 24),

          Text(
            'Saved places',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (_saved.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No saved places yet — search below.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            for (final record in _saved)
              _OptionTile(
                leading: Icon(
                  Icons.place_outlined,
                  color: AppTheme.primary,
                ),
                title: record.label ?? record.summary,
                subtitle: record.summary,
                selected: loc.manualLocation?.id == record.id,
                onTap: _picking
                    ? null
                    : () async {
                        setState(() => _picking = true);
                        final app = context.read<AppController>();
                        final nav = Navigator.of(context);
                        await app.selectManualLocation(record);
                        if (mounted) {
                          setState(() => _picking = false);
                          nav.pop();
                        }
                      },
              ),
          const SizedBox(height: 16),

          Text(
            'Search a place',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  decoration: const InputDecoration(
                    hintText: 'City, district, state or PIN',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _searching ? null : _search,
                child: _searching
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Search'),
              ),
            ],
          ),
          if (_searchError != null) ...[
            const SizedBox(height: 8),
            Text(
              _searchError!,
              style: TextStyle(color: AppTheme.danger, fontSize: 13),
            ),
          ],
          const SizedBox(height: 8),
          for (final hit in _results)
            _OptionTile(
              leading: Icon(Icons.add_location_alt_outlined,
                  color: AppTheme.info),
              title: hit.name,
              subtitle: hit.summary,
              selected: false,
              trailing: Icon(Icons.north_west, size: 16),
              onTap: _picking ? null : () => _saveAndSelect(hit),
            ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.selected,
    this.trailing,
    this.onTap,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final bool selected;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? AppTheme.primary.withValues(alpha: 0.09)
          : scheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (trailing != null)
                trailing!
              else
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: selected ? AppTheme.primary : scheme.outline,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}