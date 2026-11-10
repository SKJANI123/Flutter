import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:disaster/core/utils/launchers.dart';
import 'package:disaster/domain/entities/shelter.dart';
import 'package:disaster/presentation/providers/shelters_controller.dart';
import 'package:disaster/presentation/screens/shelters/shelter_detail_screen.dart';
import 'package:disaster/presentation/theme/app_theme.dart';
import 'package:disaster/presentation/widgets/common.dart';

class SheltersScreen extends StatelessWidget {
  const SheltersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<SheltersController>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safe Places'),
        actions: [
          if (ctrl.refreshing)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => ctrl.refresh(),
            ),
        ],
      ),
      body: _buildBody(context, ctrl),
    );
  }

  Widget _buildBody(BuildContext context, SheltersController ctrl) {
    if (ctrl.loading) return const Center(child: CircularProgressIndicator());
    if (ctrl.error != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'Could not load safe places',
        subtitle: 'Pull to retry.',
      );
    }
    if (ctrl.shelters.isEmpty) {
      return const EmptyState(
        icon: Icons.apartment_outlined,
        title: 'No safe places nearby yet',
        subtitle: 'Pull to refresh from the server.',
      );
    }
    return RefreshIndicator(
      onRefresh: () => ctrl.load(),
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: ctrl.shelters.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final s = ctrl.shelters[i];
          return _ShelterTile(shelter: s);
        },
      ),
    );
  }
}

class _ShelterTile extends StatelessWidget {
  const _ShelterTile({required this.shelter});
  final Shelter shelter;

  @override
  Widget build(BuildContext context) {
    final open = shelter.isOpen;
    return Card(
      child: ListTile(
        leading: Icon(_typeIcon(shelter.type), color: AppTheme.safe, size: 30),
        title: Text(
          shelter.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (shelter.address != null)
              Text(
                shelter.address!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 2),
            Text(
              [
                if (shelter.distanceKm != null)
                  '${shelter.distanceKm!.toStringAsFixed(1)} km',
                if (shelter.capacity != null) '${shelter.capacity} seats',
                open ? 'Open' : 'Closed',
              ].join(' · '),
              style: TextStyle(
                fontSize: 12,
                color: open
                    ? AppTheme.safe
                    : Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        isThreeLine: true,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ShelterDetailScreen(shelter: shelter),
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.directions),
          tooltip: 'Navigate',
          onPressed: () => EmergencyLaunchers.openMaps(
            lat: shelter.coordinates.latitude,
            lng: shelter.coordinates.longitude,
            label: shelter.name,
          ),
        ),
      ),
    );
  }

  IconData _typeIcon(SafePlaceType type) => switch (type) {
    SafePlaceType.shelter => Icons.apartment,
    SafePlaceType.hospital => Icons.local_hospital,
    SafePlaceType.policeStation => Icons.local_police,
    SafePlaceType.reliefCamp => Icons.volunteer_activism,
    SafePlaceType.safeZone => Icons.shield_outlined,
  };
}
