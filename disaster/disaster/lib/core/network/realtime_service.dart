import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:disaster/core/config/app_config.dart';

enum RealtimeStatus { connected, disconnected, reconnecting }

/// Automatic-reconnecting WebSocket client with exponential backoff.
///
/// Scenarios handled:
/// - server disconnect / network loss -> reconnect with backoff
/// - malformed frames -> skipped, connection kept
/// - connection stalls -> keepalive timeout forces a re-connect
/// - buffering while offline -> caller is expected to run REST catch-up
class RealtimeService {
  RealtimeService({required this._url, this._headers, Duration? pingInterval})
    : _pingInterval = pingInterval ?? const Duration(seconds: 25);

  final String _url;
  final Map<String, String>? _headers;
  final Duration _pingInterval;

  final _messagesController = StreamController<dynamic>.broadcast();
  final _statusController = StreamController<RealtimeStatus>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _pingTimer;
  bool _disposed = false;
  bool _manualClose = false;
  int _attempt = 0;
  RealtimeStatus _status = RealtimeStatus.disconnected;

  /// Parsed JSON messages (raw dynamic maps) as they arrive.
  Stream<dynamic> get messages => _messagesController.stream;

  /// Connection state changes.
  Stream<RealtimeStatus> get status => _statusController.stream;

  RealtimeStatus get currentStatus => _status;

  void _setStatus(RealtimeStatus s) {
    if (_status != s && !_disposed) {
      _status = s;
      _statusController.add(s);
    }
  }

  void connect() {
    if (_disposed || _status == RealtimeStatus.connected) return;
    _manualClose = false;
    _start();
  }

  void _start() {
    if (_disposed || _manualClose) return;
    _attempt++;
    _setStatus(
      _attempt == 1 ? RealtimeStatus.disconnected : RealtimeStatus.reconnecting,
    );

    try {
      if (_url.startsWith('wss://') || _url.startsWith('ws://')) {
        _channel = IOWebSocketChannel.connect(
          Uri.parse(_url),
          headers: _headers,
          pingInterval: _pingInterval,
        );
      } else {
        _setStatus(RealtimeStatus.disconnected);
        return;
      }
      _subscription = _channel!.stream.listen(
        _onData,
        onError: (_) => _onBroken(),
        onDone: _onBroken,
        cancelOnError: true,
      );
      _setStatus(RealtimeStatus.connected);
      _attempt = 0;
    } catch (_) {
      _onBroken();
    }
  }

  void _onData(dynamic data) {
    if (_disposed) return;
    try {
      final decoded = data is String ? jsonDecode(data) : data;
      if (!_messagesController.isClosed) {
        _messagesController.add(decoded);
      }
    } catch (_) {
      // Malformed frame -> ignore and keep the connection alive.
    }
  }

  void _onBroken() {
    if (_disposed || _manualClose) return;
    _teardown();
    if (_attempt >= AppConfig.maxReconnectAttempts) {
      _setStatus(RealtimeStatus.disconnected);
      return;
    }
    final delay = Duration(seconds: min(_attempt * 2, 30));
    Future.delayed(delay, _start);
  }

  void _teardown() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
  }

  /// Closes the connection permanently (used by the coordinator).
  void dispose() {
    _manualClose = true;
    _disposed = true;
    _teardown();
    _messagesController.close();
    _statusController.close();
  }
}

/// Helper to re-export streams under one type for keystroke cleanliness.
typedef RealtimeMessageHandler = void Function(dynamic message);
