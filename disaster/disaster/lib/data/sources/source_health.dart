import 'package:flutter/foundation.dart';

import 'package:disaster/data/sources/disaster_source.dart';

/// Live status of an official incident feed.
enum SourceState { ok, unavailable }

class SourceHealthEntry {
  const SourceHealthEntry({
    required this.sourceId,
    required this.name,
    required this.description,
    required this.state,
    this.lastSuccess,
    this.lastFailure,
    this.lastError,
    this.incidentCount = 0,
  });

  final String sourceId;
  final String name;
  final String description;
  final SourceState state;
  final DateTime? lastSuccess;
  final DateTime? lastFailure;
  final String? lastError;
  final int incidentCount;

  SourceHealthEntry copyWith({
    SourceState? state,
    DateTime? lastSuccess,
    DateTime? lastFailure,
    String? lastError,
    int? incidentCount,
  }) {
    return SourceHealthEntry(
      sourceId: sourceId,
      name: name,
      description: description,
      state: state ?? this.state,
      lastSuccess: lastSuccess ?? this.lastSuccess,
      lastFailure: lastFailure ?? this.lastFailure,
      lastError: lastError ?? this.lastError,
      incidentCount: incidentCount ?? this.incidentCount,
    );
  }
}

/// Tracks per-source availability so the UI can tell the user exactly which
/// official feeds are live and which are unreachable. Data is never faked —
/// an unreachable source is reported as *unavailable*.
class SourceHealthRegistry extends ChangeNotifier {
  SourceHealthRegistry({List<DisasterSource>? sources}) {
    sources ??= const [];
    for (final s in sources) {
      register(s);
    }
  }

  final Map<String, SourceHealthEntry> _entries = {};

  void register(DisasterSource source) {
    _entries[source.id] = SourceHealthEntry(
      sourceId: source.id,
      name: source.name,
      description: source.description,
      state: SourceState.unavailable,
    );
  }

  void markSuccess(String sourceId, int incidentCount, {DateTime? at}) {
    final current = _entries[sourceId];
    if (current == null) return;
    _entries[sourceId] = current.copyWith(
      state: SourceState.ok,
      lastSuccess: at ?? DateTime.now(),
      lastFailure: current.lastFailure,
      lastError: null,
      incidentCount: incidentCount,
    );
    notifyListeners();
  }

  void markFailure(String sourceId, Object error, {DateTime? at}) {
    final current = _entries[sourceId];
    if (current == null) return;
    _entries[sourceId] = current.copyWith(
      state: SourceState.unavailable,
      lastFailure: at ?? DateTime.now(),
      lastError: error.toString(),
      lastSuccess: current.lastSuccess,
    );
    notifyListeners();
  }

  bool has(String sourceId) => _entries.containsKey(sourceId);

  SourceHealthEntry? byId(String sourceId) => _entries[sourceId];

  List<SourceHealthEntry> get entries =>
      _entries.values.toList(growable: false);

  /// Sources that are configured but currently unreachable.
  List<SourceHealthEntry> get unavailable =>
      entries.where((e) => e.state == SourceState.unavailable).toList();

  int get liveCount => entries.where((e) => e.state == SourceState.ok).length;

  int get configuredCount => entries.length;
}
