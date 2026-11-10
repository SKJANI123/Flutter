import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:disaster/core/utils/geo_distance.dart';
import 'package:disaster/domain/entities/shelter.dart';
import 'package:disaster/presentation/providers/app_dependencies.dart';
import 'package:disaster/presentation/providers/location_controller.dart';

class SheltersController extends ChangeNotifier {
  SheltersController({required this._deps, required this._location}) {
    _location.addListener(_changed);
    load();
  }

  final AppDependencies _deps;
  final LocationController _location;

  List<Shelter> _shelters = [];
  List<Shelter> get shelters => _shelters;
  bool _loading = true;
  bool get loading => _loading;
  Object? _error;
  Object? get error => _error;
  bool _refreshing = false;
  bool get refreshing => _refreshing;

  Future<void> load({bool showLoading = true}) async {
    if (showLoading) _loading = true;
    notifyListeners();
    try {
      final all = await _deps.shelters.getAll();
      final user = _location.activeLocationCoords ?? _location.lastLocation;
      final sorted =
          all.map((s) {
            final d = user == null
                ? null
                : GeoDistance.haversineKm(user, s.coordinates);
            return s.withDistanceKm(d);
          }).toList()..sort(
            (a, b) => (a.distanceKm ?? double.infinity).compareTo(
              b.distanceKm ?? double.infinity,
            ),
          );
      _shelters = sorted;
      _error = null;
    } on Object catch (e) {
      _error = e;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Fetch fresh shelter data from the API and cache it (offline-first).
  Future<void> refresh() async {
    _refreshing = true;
    notifyListeners();
    try {
      final fetched = await _deps.shelterRemote.fetchShelters();
      if (fetched.isNotEmpty) {
        await _deps.shelters.upsertAll(fetched);
      }
      await load(showLoading: false);
    } on Object catch (e) {
      _error = e;
    } finally {
      _refreshing = false;
      notifyListeners();
    }
  }

  void _changed([dynamic _]) {
    load(showLoading: false);
  }

  @override
  void dispose() {
    _location.removeListener(_changed);
    super.dispose();
  }
}
