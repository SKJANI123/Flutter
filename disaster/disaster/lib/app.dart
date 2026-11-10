import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:disaster/core/network/connectivity_service.dart';
import 'package:disaster/presentation/navigation/navigator_keys.dart';
import 'package:disaster/presentation/providers/alerts_controller.dart';
import 'package:disaster/presentation/providers/app_controller.dart';
import 'package:disaster/presentation/providers/app_dependencies.dart';
import 'package:disaster/presentation/providers/contacts_controller.dart';
import 'package:disaster/presentation/providers/history_controller.dart';
import 'package:disaster/presentation/providers/home_controller.dart';
import 'package:disaster/presentation/providers/location_controller.dart';
import 'package:disaster/presentation/providers/map_controller.dart';
import 'package:disaster/presentation/providers/shelters_controller.dart';
import 'package:disaster/presentation/providers/sos_controller.dart';
import 'package:disaster/presentation/screens/splash/splash_screen.dart';
import 'package:disaster/presentation/theme/app_theme.dart';

/// Root widget. Constructs and wires all controllers (disposed on teardown)
/// and exposes them through Provider.
class DisasterApp extends StatefulWidget {
  const DisasterApp({super.key, required this.deps});

  final AppDependencies deps;

  @override
  State<DisasterApp> createState() => _DisasterAppState();
}

class _DisasterAppState extends State<DisasterApp> {
  late final LocationController _locationController;
  late final AppController _appController;
  late final AlertsController _alertsController;
  late final HomeController _homeController;
  late final SosController _sosController;
  late final ContactsController _contactsController;
  late final SheltersController _sheltersController;
  late final HistoryController _historyController;
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    final deps = widget.deps;
    _locationController = LocationController(deps: deps);
    _appController = AppController(
      deps: deps,
      locationController: _locationController,
    );
    _alertsController = AlertsController(
      deps: deps,
      locationController: _locationController,
    );
    _homeController = HomeController(
      deps: deps,
      location: _locationController,
      alerts: _alertsController,
    );
    _sosController = SosController(deps: deps, location: _locationController);
    _contactsController = ContactsController(deps: deps);
    _sheltersController = SheltersController(
      deps: deps,
      location: _locationController,
    );
    _historyController = HistoryController(deps: deps);
    _mapController = MapController(
      deps: deps,
      location: _locationController,
      alerts: _alertsController,
      shelters: _sheltersController,
    );
  }

  @override
  void dispose() {
    _historyController.dispose();
    _sheltersController.dispose();
    _contactsController.dispose();
    _sosController.dispose();
    _homeController.dispose();
    _alertsController.dispose();
    _appController.dispose();
    _locationController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppDependencies>.value(value: widget.deps),
        Provider<ConnectivityService>.value(value: widget.deps.connectivity),
        ChangeNotifierProvider<LocationController>.value(
          value: _locationController,
        ),
        ChangeNotifierProvider<AppController>.value(value: _appController),
        ChangeNotifierProvider<AlertsController>.value(
          value: _alertsController,
        ),
        ChangeNotifierProvider<HomeController>.value(value: _homeController),
        ChangeNotifierProvider<SosController>.value(value: _sosController),
        ChangeNotifierProvider<ContactsController>.value(
          value: _contactsController,
        ),
        ChangeNotifierProvider<SheltersController>.value(
          value: _sheltersController,
        ),
        ChangeNotifierProvider<HistoryController>.value(
          value: _historyController,
        ),
        ChangeNotifierProvider<MapController>.value(value: _mapController),
      ],
      child: const _AppView(),
    );
  }
}

class _AppView extends StatelessWidget {
  const _AppView();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    return MaterialApp(
      title: 'Disaster Alert',
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: app.themeMode,
      builder: (context, child) => _applySurfaces(context, child),
      home: const SplashScreen(),
    );
  }

  Widget _applySurfaces(BuildContext context, Widget? child) {
    // Emergency alert colors should not be affected by overlay surfaces.
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: MediaQuery.of(context).textScaler
            .clamp(minScaleFactor: 0.85, maxScaleFactor: 1.4),
      ),
      child: child ?? const SizedBox.shrink(),
    );
  }
}
