import 'dart:async';

import 'package:disaster/core/config/app_config.dart';
import 'package:disaster/core/errors/exceptions.dart';
import 'package:disaster/core/network/connectivity_service.dart';
import 'package:disaster/core/network/realtime_service.dart';
import 'package:disaster/data/remote/models/disaster_event.dart';
import 'package:disaster/data/remote/repositories/disaster_remote_repository.dart';
import 'package:disaster/domain/enums/disaster_status.dart';
import 'package:disaster/domain/services/alert_pipeline.dart';

enum RealtimeState { starting, live, polling, offline, error }

/// Coordinates the real-time alert flow for production (server) data:
///
/// WebSocket stream (with auto-reconnect) -> parse -> pipeline
/// REST periodic polling as a fallback when WebSocket is down / after
/// reconnects to fetch anything missed while offline.
///
/// Re-uses [AlertPipeline] so events are de-duplicated, persisted and rated
/// exactly like simulator events.
class DisasterRealtimeService {
  DisasterRealtimeService({
    required this._socket,
    required this._remote,
    required this._pipeline,
    required this._connectivity,
  });

  final RealtimeService _socket;
  final DisasterRemoteRepository _remote;
  final AlertPipeline _pipeline;
  final ConnectivityService _connectivity;

  Timer? _pollTimer;
  StreamSubscription<dynamic>? _socketSub;
  StreamSubscription<bool>? _connectivitySub;
  final _stateController = StreamController<RealtimeState>.broadcast();
  RealtimeState _state = RealtimeState.offline;

  Stream<RealtimeState> get state => _stateController.stream;
  RealtimeState get currentState => _state;

  /// Start the real-time flow (WebSocket + polling fallback).
  void start() {
    _setState(RealtimeState.starting);

    _socketSub = _socket.messages.listen((message) {
      _handleIncoming(message);
    });

    _connectivitySub = _connectivity.onChanged.listen((online) {
      if (online) {
        _socket.connect();
      }
    });

    _socket.connect();
    _startPolling();

    if (_connectivity.isOnline) {
      _pollNow();
    } else {
      _setState(RealtimeState.offline);
    }
  }

  Future<void> _handleIncoming(dynamic message) async {
    final disaster = DisasterEventParser.tryParseSingle(message);
    if (disaster == null) return; // heartbeat / ack / malformed
    if (disaster.provider != DataProvider.server) return;
    await _pipeline.process(disaster);
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      Duration(seconds: AppConfig.pollIntervalSeconds),
      (_) => _pollNow(),
    );
  }

  Future<void> _pollNow() async {
    if (!_connectivity.isOnline) return;
    try {
      final list = await _remote.fetchDisasters();
      if (list.isNotEmpty) {
        for (final d in list) {
          await _pipeline.process(d);
        }
        _setState(RealtimeState.polling);
      }
    } on NetworkException {
      _setState(RealtimeState.offline);
    } on ApiException {
      // Server error — keep whatever state we're in.
    } catch (_) {
      // Malformed data is ignored; never fatal.
    }
  }

  /// Manual catch-up trigger (used right after a WebSocket reconnect).
  Future<void> catchUp() => _pollNow();

  void _setState(RealtimeState s) {
    if (_state != s) {
      _state = s;
      if (!_stateController.isClosed) _stateController.add(s);
    }
  }

  void dispose() {
    _pollTimer?.cancel();
    _connectivitySub?.cancel();
    _socketSub?.cancel();
    _socket.dispose();
    _stateController.close();
  }
}
