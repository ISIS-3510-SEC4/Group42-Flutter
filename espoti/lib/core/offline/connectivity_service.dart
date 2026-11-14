import 'dart:async';
import 'dart:io' show InternetAddress, SocketException;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Service that monitors device connectivity using [Connectivity] from
/// connectivity_plus, validated with a DNS probe against Firestore.
class ConnectivityService {
  ConnectivityService._() {
    _initListener();
  }

  /// Singleton instance
  static final ConnectivityService instance = ConnectivityService._();

  static const String _probeHost = 'firestore.googleapis.com';
  static const Duration _timeout = Duration(seconds: 4);

  final ValueNotifier<bool> isOnline = ValueNotifier<bool>(true);

  Future<bool>? _inFlight;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  final Connectivity _connectivity = Connectivity();

  void _initListener() {
    try {
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) {
        final hasConnection = results.any((r) => r != ConnectivityResult.none);
        if (!hasConnection) {
          _set(false);
        } else {
          // Verify actual reachability with DNS probe
          check();
        }
      });
    } catch (e) {
      debugPrint('ConnectivityService: Failed to attach connectivity_plus listener: $e');
    }
  }

  /// Public method to verify connectivity.
  Future<bool> check() =>
      _inFlight ??= _probe().whenComplete(() => _inFlight = null);

  Future<bool> _probe() async {
    if (kIsWeb) return _set(true);

    try {
      // First check platform connectivity
      final statusList = await _connectivity.checkConnectivity();
      if (statusList.every((r) => r == ConnectivityResult.none)) {
        return _set(false);
      }

      // Perform DNS query against Firestore endpoint
      final result = await InternetAddress.lookup(_probeHost).timeout(_timeout);
      return _set(result.isNotEmpty && result.first.rawAddress.isNotEmpty);
    } on SocketException {
      return _set(false);
    } on TimeoutException {
      return _set(false);
    } catch (_) {
      return _set(false);
    }
  }

  bool _set(bool online) {
    if (isOnline.value != online) {
      isOnline.value = online;
      debugPrint('ConnectivityService: Network state changed -> online: $online');
    }
    return online;
  }

  void reportNetworkFailure() => _set(false);

  @visibleForTesting
  void dispose() {
    _connectivitySubscription?.cancel();
  }
}
