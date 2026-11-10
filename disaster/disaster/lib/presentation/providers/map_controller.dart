import 'package:flutter/foundation.dart';

import 'package:disaster/domain/entities/disaster.dart';
import 'package:disaster/domain/entities/shelter.dart';
import 'package:disaster/domain/value_objects/coordinates.dart';
import 'package:disaster/presentation/providers/alerts_controller.dart';
import 'package:disaster/presentation/providers/app_dependencies.dart';
import 'package:disaster/presentation/providers/location_controller.dart';
import 'package:disaster/presentation/providers/shelters_controller.dart';

/// State for the live map screen: markers for the user, disasters (with
/// affected-radius circles) and shelters.
class MapController extends ChangeNotifier {
  MapController({
    required AppDependencies deps,
    required this._location,
    required this._alerts,
    required this._shelters,
  }) {
    _location.addListener(_changed);
    _alerts.addListener(_changed);
    _shelters.addListener(_changed);
  }

  final LocationController _location;
  final AlertsController _alerts;
  final SheltersController _shelters;

  Coordinates? get userLocation =>
      _location.activeLocationCoords ?? _location.lastLocation;
  List<Disaster> get disasters => _alerts.items.map((i) => i.disaster).toList();
  List<Shelter> get shelters => _shelters.shelters;
  bool get showShelters => true;

  void _changed([dynamic _]) => notifyListeners();

  @override
  void dispose() {
    _location.removeListener(_changed);
    _alerts.removeListener(_changed);
    _shelters.removeListener(_changed);
    super.dispose();
  }
}
