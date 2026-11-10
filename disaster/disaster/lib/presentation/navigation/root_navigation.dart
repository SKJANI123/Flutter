import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:disaster/presentation/screens/home/home_screen.dart';
import 'package:disaster/presentation/screens/live_alerts/live_alerts_screen.dart';
import 'package:disaster/presentation/screens/live_map/live_map_screen.dart';
import 'package:disaster/presentation/screens/sos/sos_screen.dart';
import 'package:disaster/presentation/screens/settings/settings_screen.dart';
import 'package:disaster/core/network/connectivity_service.dart';

/// Bottom navigation shell: Home, Live Alerts, Map, SOS, More.
class RootNavigation extends StatefulWidget {
  const RootNavigation({super.key});

  @override
  State<RootNavigation> createState() => _RootNavigationState();
}

class _RootNavigationState extends State<RootNavigation> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final showOffline = context.watch<ConnectivityService>().isOnline == false;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          HomeScreen(),
          LiveAlertsScreen(),
          LiveMapScreen(),
          SosScreen(),
          _MoreFromNav(),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showOffline)
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.error,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off, size: 16, color: Colors.white),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Offline — showing cached alerts. Will sync when back online.',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          NavigationBar(
            selectedIndex: _index,
            backgroundColor: isDark ? Colors.black12 : null,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.crisis_alert_outlined),
                selectedIcon: Icon(Icons.crisis_alert),
                label: 'Alerts',
              ),
              NavigationDestination(
                icon: Icon(Icons.map_outlined),
                selectedIcon: Icon(Icons.map),
                label: 'Map',
              ),
              NavigationDestination(
                icon: Icon(Icons.sos_outlined),
                selectedIcon: Icon(Icons.sos),
                label: 'SOS',
              ),
              NavigationDestination(
                icon: Icon(Icons.menu),
                selectedIcon: Icon(Icons.menu),
                label: 'More',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MoreFromNav extends StatelessWidget {
  const _MoreFromNav();

  @override
  Widget build(BuildContext context) {
    return const SettingsScreen();
  }
}
