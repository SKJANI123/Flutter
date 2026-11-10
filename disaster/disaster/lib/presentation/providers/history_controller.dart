import 'package:flutter/foundation.dart';

import 'package:disaster/domain/entities/alert_history_entry.dart';
import 'package:disaster/domain/enums/alert_level.dart';
import 'package:disaster/domain/enums/disaster_type.dart';
import 'package:disaster/presentation/providers/app_dependencies.dart';

class HistoryController extends ChangeNotifier {
  HistoryController({required this._deps}) {
    load();
  }

  final AppDependencies _deps;

  List<AlertHistoryEntry> _entries = [];
  List<AlertHistoryEntry> get entries => _entries;
  bool _loading = true;
  bool get loading => _loading;
  Object? _error;
  Object? get error => _error;

  String _query = '';
  List<DisasterType> _types = [];
  AlertLevel? _minLevel;

  String get query => _query;
  List<DisasterType> get types => _types;
  AlertLevel? get minLevel => _minLevel;

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    try {
      _entries = await _deps.history.search(
        query: _query.isEmpty ? null : _query,
        types: _types.isEmpty ? null : _types,
        minLevel: _minLevel,
      );
      _error = null;
    } on Object catch (e) {
      _error = e;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void setQuery(String q) {
    _query = q;
    load();
  }

  void toggleType(DisasterType t) {
    if (_types.contains(t)) {
      _types.remove(t);
    } else {
      _types.add(t);
    }
    load();
  }

  void setMinLevel(AlertLevel? level) {
    _minLevel = level;
    load();
  }

  void clearFilters() {
    _query = '';
    _types = [];
    _minLevel = null;
    load();
  }
}
