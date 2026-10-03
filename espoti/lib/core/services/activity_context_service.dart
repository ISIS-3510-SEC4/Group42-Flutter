import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Motion context derived from the accelerometer.
enum MotionState {
  unknown, // not enough data yet
  stationary,
  moving,
  unavailable, // no accelerometer / sensor error
}

/// Detects whether the user is moving or stationary using the accelerometer.
///
/// This service ONLY detects movement; it never provides a position. GPS and
/// Firestore updates are done by `LocationSharingService`, which observes
/// [stateNotifier] (same ValueNotifier observer mechanism as `UserService`).
/// The accelerometer needs no runtime permission on Android/iOS.
class ActivityContextService {
  static final ActivityContextService _instance =
      ActivityContextService._internal();
  factory ActivityContextService() => _instance;
  ActivityContextService._internal();

  static const double _gravity = 9.80665;
  static const int _windowSize = 10; // ~2 s at 200 ms sampling
  static const double _movingThreshold = 1.0; // m/s² mean deviation from g
  static const double _stationaryThreshold = 0.5;
  static const int _windowsToMove = 2; // ~4 s of movement
  static const int _windowsToStop = 5; // ~10 s still, avoids flapping

  final ValueNotifier<MotionState> stateNotifier =
      ValueNotifier<MotionState>(MotionState.unknown);

  MotionState get state => stateNotifier.value;
  bool get isMoving => state == MotionState.moving;
  bool get isSupported => state != MotionState.unavailable;

  StreamSubscription<AccelerometerEvent>? _subscription;
  final List<double> _window = [];
  int _movingVotes = 0;
  int _stationaryVotes = 0;

  /// Starts listening. Safe to call more than once.
  void start() {
    if (_subscription != null) return;
    stateNotifier.value = MotionState.unknown;
    try {
      _subscription = accelerometerEventStream(
        samplingPeriod: SensorInterval.normalInterval,
      ).listen(
        _onEvent,
        onError: (Object error) {
          debugPrint('Accelerometer error: $error');
          _markUnavailable();
        },
        cancelOnError: true,
      );
    } catch (e) {
      // e.g. MissingPluginException on unsupported platforms.
      debugPrint('Accelerometer unavailable: $e');
      _markUnavailable();
    }
  }

  /// Stops listening to save battery.
  void stop() {
    _subscription?.cancel();
    _subscription = null;
    _window.clear();
    _movingVotes = 0;
    _stationaryVotes = 0;
    stateNotifier.value = MotionState.unknown;
  }

  void _markUnavailable() {
    _subscription = null;
    stateNotifier.value = MotionState.unavailable;
  }

  void _onEvent(AccelerometerEvent e) {
    final magnitude = math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
    _window.add((magnitude - _gravity).abs());
    if (_window.length < _windowSize) return;

    final mean = _window.reduce((a, b) => a + b) / _window.length;
    _window.clear();

    if (mean > _movingThreshold) {
      _movingVotes++;
      _stationaryVotes = 0;
    } else if (mean < _stationaryThreshold) {
      _stationaryVotes++;
      _movingVotes = 0;
    }

    if (_movingVotes >= _windowsToMove) {
      if (stateNotifier.value != MotionState.moving) {
        debugPrint('Accelerometer: MOVING');
      }
      stateNotifier.value = MotionState.moving;
    } else if (_stationaryVotes >= _windowsToStop) {
      if (stateNotifier.value != MotionState.stationary) {
        debugPrint('Accelerometer: STATIONARY');
      }
      stateNotifier.value = MotionState.stationary;
    }
  }
}
