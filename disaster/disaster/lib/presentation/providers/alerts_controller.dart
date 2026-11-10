import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:disaster/core/utils/geo_distance.dart';
import 'package:disaster/domain/entities/disaster.dart';
import 'package:disaster/domain/enums/alert_level.dart';
import 'package:disaster/domain/enums/disaster_status.dart';
import 'package:disaster/domain/enums/disaster_type.dart';
import 'package:disaster/domain/enums/severity.dart';
import 'package:disaster/presentation/providers/app_dependencies.dart';
import 'package:disaster/presentation/providers/location_controller.dart';

class DisasterListItem {
  DisasterListItem(this.disaster, this.level, this.distanceKm);
  final Disaster disaster;
  final AlertLevel level;
  final double? distanceKm;
}

/// Live list of disasters with the user's assessed level and distance.
class AlertsController extends ChangeNotifier {
  AlertsController({
    required this._deps,
    required LocationController locationController,
  }) : _location = locationController {
    _deps.pipeline.results.listen((r) {
      _refresh();
    });
    _location.addListener(_refresh);
    _refresh();
  }

  final AppDependencies _deps;
  final LocationController _location;

  List<DisasterListItem> _items = [];
  List<DisasterListItem> _masterItems = [];
  List<DisasterListItem> get items => _items;

  /// Pre-section, filter-applied views used by the home "sections".
  List<DisasterListItem> get allItems => _masterItems;
  List<DisasterListItem> get criticalItems => _masterItems
      .where((i) => i.level == AlertLevel.critical)
      .toList();
  List<DisasterListItem> get nearbyItems => _masterItems
      .where((i) => i.distanceKm != null)
      .where((i) => i.distanceKm! <= _alertRadiusKm)
      .toList();
  List<DisasterListItem> get recentItems => _masterItems
      .where(
        (i) =>
            (i.disaster.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                .isAfter(DateTime.now().subtract(const Duration(hours: 24))),
      )
      .toList();
  int get activeCount =>
      _items.where((i) => i.disaster.status == DisasterStatus.active).length;

  String _providerFilter = 'all';
  String get providerFilter => _providerFilter;
  bool get showingSimulator => _providerFilter == 'simulator';
  bool get showingServer => _providerFilter == 'server';

  List<DisasterType> _typeFilter = [];
  bool get hasTypeFilter => _typeFilter.isNotEmpty;

  Severity? _severityFilter;
  double? _maxDistanceKm;
  DateTime? _fromDate;

  Severity? get severityFilter => _severityFilter;
  double? get maxDistanceKm => _maxDistanceKm;
  DateTime? get dateFilter => _fromDate;

  bool get hasFilters =>
      _typeFilter.isNotEmpty ||
      _severityFilter != null ||
      _maxDistanceKm != null ||
      _fromDate != null;

  /// Section modes for the alerts list.
  static const String sectionAll = 'all';
  static const String sectionNearby = 'nearby';
  static const String sectionCritical = 'critical';
  static const String sectionRecent = 'recent';

  /// Normalizes a section id (unknown ids fall back to "all").
  static String sectionFrom(String id) => switch (id) {
        sectionNearby => sectionNearby,
        sectionCritical => sectionCritical,
        sectionRecent => sectionRecent,
        _ => sectionAll,
      };

  String _section = sectionAll;
  String get section => _section;

  bool _loading = true;
  bool get loading => _loading;
  Object? _error;
  Object? get error => _error;

  void setSection(String section) {
    if (_section == section) return;
    _section = section;
    _refresh();
  }

  void setProviderFilter(String provider) {
    if (_providerFilter == provider) return;
    _providerFilter = provider;
    _refresh();
  }

  void setSeverityFilter(Severity? severity) {
    if (_severityFilter == severity) return;
    _severityFilter = severity;
    _refresh();
  }

  void setMaxDistanceKm(double? km) {
    if (_maxDistanceKm == km) return;
    _maxDistanceKm = km;
    _refresh();
  }

  void setDateFilter(DateTime? from) {
    if (_fromDate == from) return;
    _fromDate = from;
    _refresh();
  }

  void clearFilters() {
    _providerFilter = 'all';
    _typeFilter = [];
    _severityFilter = null;
    _maxDistanceKm = null;
    _fromDate = null;
    _refresh();
  }

  void toggleTypeFilter(DisasterType type) {
    if (_typeFilter.contains(type)) {
      _typeFilter.remove(type);
    } else {
      _typeFilter.add(type);
    }
    _refresh();
  }

  void clearTypeFilter() {
    if (_typeFilter.isEmpty) return;
    _typeFilter = [];
    _refresh();
  }

  Future<void> refresh({bool showLoading = true}) async {
    if (showLoading) _loading = true;
    notifyListeners();
    try {
      final settings = await _deps.settings.load();
      _alertRadiusKm = settings.alertRadiusKm;
      final all = await _deps.disasters.findAllActive();
      final levelItems = _build(all);
      _items = levelItems;
      _error = null;
    } on Object catch (e) {
      _error = e;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  List<DisasterListItem> _build(List<Disaster> all) {
    final user = _location.activeLocationCoords ?? _location.lastLocation;
    final filtered =
        all
            .where(
              (d) =>
                  _providerFilter == 'all' ||
                  d.provider.value == _providerFilter,
            )
            .where((d) => _typeFilter.isEmpty || _typeFilter.contains(d.type))
            .toList()
          ..sort(
            (a, b) => (b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                .compareTo(
                  a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
                ),
          );

    final items = filtered.map((d) {
      double? distance;
      AlertLevel level = AlertLevel.safe;
      if (user != null) {
        distance = GeoDistance.haversineKm(user, d.coordinates);
        level = d.levelForDistance(distance);
      } else {
        level = AlertLevel.values.firstWhere(
          (l) =>
              l.weight ==
              d.severity.weight.clamp(0, AlertLevel.critical.weight),
        );
      }
      return DisasterListItem(d, level, distance);
    }).toList();

    // Section filtering.
    final sectioned = switch (_section) {
      sectionNearby => items
          .where((i) => i.distanceKm != null)
          .where((i) => i.distanceKm! <= _alertRadiusKm)
          .toList(),
      sectionCritical => items.where((i) => i.level == AlertLevel.critical).toList(),
      sectionRecent => items
          .where(
            (i) =>
                (i.disaster.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                    .isAfter(DateTime.now().subtract(const Duration(hours: 24))),
          )
          .toList(),
      _ => items,
    };
    _masterItems = items;

    // Additional severity / distance / date filters.
    return sectioned
        .where((i) => _severityFilter == null || i.disaster.severity == _severityFilter)
        .where(
          (i) =>
              _maxDistanceKm == null ||
              (i.distanceKm != null && i.distanceKm! <= _maxDistanceKm!),
        )
        .where(
          (i) =>
              _fromDate == null ||
              ((i.disaster.updatedAt ??
                      DateTime.fromMillisecondsSinceEpoch(0))
                  .isAfter(_fromDate!)),
        )
        .toList();
  }

  double _alertRadiusKm = 25.0;

  int get count => _items.length;

  void _refresh() async {
    await refresh(showLoading: false);
  }

  @override
  void dispose() {
    _location.removeListener(_refresh);
    super.dispose();
  }
}
