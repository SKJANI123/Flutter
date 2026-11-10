import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:latlong2/latlong.dart';

import 'package:disaster/core/utils/launchers.dart';
import 'package:disaster/domain/entities/shelter.dart';
import 'package:disaster/presentation/theme/app_theme.dart';

class ShelterDetailScreen extends StatelessWidget {
  const ShelterDetailScreen({super.key, required this.shelter});

  final Shelter shelter;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(shelter.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            height: 200,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
            child: fm.FlutterMap(
              options: fm.MapOptions(
                initialCenter: LatLng(
                  shelter.coordinates.latitude,
                  shelter.coordinates.longitude,
                ),
                initialZoom: 14,
                interactionOptions: const fm.InteractionOptions(
                  flags: fm.InteractiveFlag.all & ~fm.InteractiveFlag.rotate,
                ),
              ),
              children: [
                fm.TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.disaster_alert',
                ),
                fm.MarkerLayer(
                  markers: [
                    fm.Marker(
                      point: LatLng(
                        shelter.coordinates.latitude,
                        shelter.coordinates.longitude,
                      ),
                      width: 44,
                      height: 44,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.safe,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 6),
                          ],
                        ),
                        child: const Icon(
                          Icons.apartment,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _Row(
                    icon: Icons.place,
                    text: shelter.address ?? 'Address not available',
                  ),
                  if (shelter.phone != null) ...[
                    const Divider(),
                    _Row(icon: Icons.phone, text: shelter.phone!),
                  ],
                  const Divider(),
                  _Row(
                    icon: Icons.people_outline,
                    text: shelter.capacity == null
                        ? 'Capacity unknown'
                        : 'Capacity: ${shelter.capacity}',
                  ),
                  const Divider(),
                  _Row(
                    icon: shelter.isOpen ? Icons.check_circle : Icons.cancel,
                    text: shelter.isOpen ? 'Open now' : 'Closed',
                    color: shelter.isOpen
                        ? AppTheme.safe
                        : Theme.of(context).colorScheme.error,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.safe),
                  onPressed: () => EmergencyLaunchers.openMaps(
                    lat: shelter.coordinates.latitude,
                    lng: shelter.coordinates.longitude,
                    label: shelter.name,
                  ),
                  icon: const Icon(Icons.directions),
                  label: const Text('Navigate'),
                ),
              ),
              if (shelter.phone != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => EmergencyLaunchers.call(shelter.phone!),
                    icon: const Icon(Icons.call),
                    label: const Text('Call'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.text, this.color});
  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: color ?? Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
        ],
      ),
    );
  }
}
