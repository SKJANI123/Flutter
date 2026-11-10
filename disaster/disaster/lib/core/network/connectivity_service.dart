import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Watches network connectivity and exposes an online/offline stream.
///
/// Wraps `connectivity_plus` so the rest of the app never depends on the
/// plugin directly and tests can inject a fake.
class ConnectivityService {
  ConnectivityService({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity() {
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      _setOnline(_hasInternet(results));
    });
    _init();
  }

  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  final _controller = StreamController<bool>.broadcast();
  bool _isOnline = false;

  /// Whether a usable internet connection is present right now.
  bool get isOnline => _isOnline;

  /// Emits whenever connectivity changes.
  Stream<bool> get onChanged => _controller.stream;

  Future<void> _init() async {
    try {
      final r = await _connectivity.checkConnectivity();
      _setOnline(_hasInternet(r));
    } catch (_) {
      // Never crash on connectivity probes; default to online so that API
      // calls still attempt (and fail gracefully) if the platform is odd.
      _setOnline(true);
    }
  }

  bool _hasInternet(List<ConnectivityResult> results) {
    return results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.mobile) ||
        results.contains(ConnectivityResult.ethernet) ||
        results.contains(ConnectivityResult.vpn);
  }

  void _setOnline(bool online) {
    if (_isOnline != online) {
      _isOnline = online;
      _controller.add(online);
    }
  }

  /// For tests / manual probing.
  void forceOnline(bool online) => _setOnline(online);

  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}
