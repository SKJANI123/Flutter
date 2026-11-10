import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:disaster/domain/entities/disaster.dart';
import 'package:disaster/domain/enums/alert_level.dart';
import 'package:disaster/domain/value_objects/coordinates.dart';
import 'package:disaster/presentation/providers/alerts_controller.dart';
import 'package:disaster/presentation/providers/app_dependencies.dart';
import 'package:disaster/presentation/providers/location_controller.dart';

class HomeCard {
  HomeCard(this.disaster, this.level, this.distanceKm);
  final Disaster disaster;
  final AlertLevel level;
  final double? distanceKm;
}

/// Dashboard statistics and the "nearest threat" card.
class HomeController extends ChangeNotifier {
  HomeController({
    required AppDependencies deps,
    required this._location,
    required this._alerts,
  }) {
    _location.addListener(_changed);
    _alerts.addListener(_changed);
    _init();
  }

  final LocationController _location;
  final AlertsController _alerts;

  List<HomeCard> _cards = [];
  List<HomeCard> get cards => _cards;
  int get activeCount => _alerts.activeCount;
  int get last24hCount {
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    return _alerts.allItems
        .where(
          (i) =>
              (i.disaster.updatedAt ??
                      i.disaster.occurredAt ??
                      DateTime.fromMillisecondsSinceEpoch(0))
                  .isAfter(cutoff),
        )
        .length;
  }
  Coordinates? get userLocation =>
      _location.activeLocationCoords ?? _location.lastLocation;

  Future<void> _init() async {
    _recompute();
  }

  void _changed([dynamic _]) {
    _recompute();
  }

  Future<void> refresh() async {
    await _recompute();
  }

  Future<void> _recompute() async {
    final live = _alerts.items;
    final ranked =
        live
            .where((i) => i.level.isActive)
            .map((i) => HomeCard(i.disaster, i.level, i.distanceKm))
            .toList()
          ..sort((a, b) => b.level.weight.compareTo(a.level.weight));
    _cards = ranked.take(4).toList();
    notifyListeners();
  }

  AlertLevel get worstLevel {
    if (_cards.isEmpty) return AlertLevel.safe;
    return _cards
        .map((c) => c.level)
        .reduce((a, b) => a.weight >= b.weight ? a : b);
  }

  String get summaryText {
    switch (worstLevel) {
      case AlertLevel.critical:
        return 'Take immediate protective action.';
      case AlertLevel.danger:
        return 'Seek safe shelter now.';
      case AlertLevel.warning:
        return 'Be alert and monitor updates.';
      default:
        return 'You are in a safe zone.';
    }
  }

  @override
  void dispose() {
    _location.removeListener(_changed);
    _alerts.removeListener(_changed);
    super.dispose();
  }
}
