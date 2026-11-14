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

/// Lectura que la interfaz muestra en vivo (pantalla "Motion sensor" y
/// detalle de la reunión). Todos los valores vienen del sensor; si no hay
/// sensor no se generan lecturas (nunca se simulan).
@immutable
class MotionReading {
  /// Aceleración medida en cada eje (m/s², incluye la gravedad).
  final double x;
  final double y;
  final double z;

  /// |a| - g: cuánto se aleja la aceleración total de la gravedad (m/s²).
  /// En reposo es cercano a 0; al caminar o agitar el teléfono sube.
  final double deviation;

  /// Promedio de [deviation] en la última ventana completa (~2 s); es el
  /// valor que se compara con los umbrales. Null hasta llenar la primera.
  final double? windowMean;

  final DateTime at;

  const MotionReading({
    required this.x,
    required this.y,
    required this.z,
    required this.deviation,
    required this.windowMean,
    required this.at,
  });
}

/// Detects whether the user is moving or stationary using the accelerometer.
///
/// Funcionamiento:
///  1. Se leen muestras del acelerómetro cada ~200 ms (normalInterval).
///  2. De cada muestra se calcula |a| - g (la magnitud menos la gravedad).
///  3. Cada [windowSize] muestras (~2 s) se promedia esa desviación.
///  4. Promedio > [movingThreshold] = ventana "en movimiento";
///     promedio < [stationaryThreshold] = ventana "quieto"; entre ambos no
///     cambia nada (histéresis, evita parpadeos).
///  5. Hacen falta [windowsToMove] ventanas seguidas (~4 s) para pasar a
///     moving y [windowsToStop] (~10 s) para pasar a stationary.
///
/// This service ONLY detects movement; it never provides a position. GPS and
/// Firestore updates are done by `LocationSharingService`, which observes
/// [stateNotifier]. The accelerometer needs no runtime permission on
/// Android/iOS.
///
/// Varias pantallas pueden necesitar el sensor a la vez (el uso compartido de
/// ubicación y la pantalla "Motion sensor"); por eso [start] y [stop] reciben
/// un "dueño" y el sensor solo se apaga cuando ya no queda ninguno.
class ActivityContextService {
  static final ActivityContextService _instance =
      ActivityContextService._internal();
  factory ActivityContextService() => _instance;
  ActivityContextService._internal();

  static const double gravity = 9.80665; // m/s²
  static const int windowSize = 10; // ~2 s at 200 ms sampling
  static const double movingThreshold = 1.0; // m/s² mean deviation from g
  static const double stationaryThreshold = 0.5; // m/s²
  static const int windowsToMove = 2; // ~4 s of movement
  static const int windowsToStop = 5; // ~10 s still, avoids flapping

  final ValueNotifier<MotionState> stateNotifier =
      ValueNotifier<MotionState>(MotionState.unknown);

  /// Última lectura del sensor (null si no hay sensor o aún no llegan datos).
  final ValueNotifier<MotionReading?> readingNotifier =
      ValueNotifier<MotionReading?>(null);

  MotionState get state => stateNotifier.value;
  bool get isMoving => state == MotionState.moving;
  bool get isSupported => state != MotionState.unavailable;

  StreamSubscription<AccelerometerEvent>? _subscription;
  // Dueños del sensor (pantalla Motion sensor y LocationSharingService): el
  // stream solo se cancela cuando ya no queda ninguno.
  final Set<Object> _owners = {};
  final List<double> _window = [];
  double? _lastWindowMean;
  int _movingVotes = 0;
  int _stationaryVotes = 0;

  /// Starts listening for [owner]. Safe to call more than once.
  void start({Object owner = 'default'}) {
    _owners.add(owner);
    if (_subscription != null || state == MotionState.unavailable) return;
    _reset();
    try {
      // Disponibilidad: si la plataforma no tiene sensor (web, algunos
      // emuladores) el stream falla en onError o lanza al crearse; en ambos
      // casos el estado pasa a unavailable y no se generan lecturas simuladas.
      // cancelOnError corta el stream al primer error.
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

  /// [owner] no longer needs the sensor; it stops (to save battery) when no
  /// owner is left.
  void stop({Object owner = 'default'}) {
    _owners.remove(owner);
    if (_owners.isNotEmpty) return;
    _subscription?.cancel();
    _subscription = null;
    _reset();
  }

  void _reset() {
    _window.clear();
    _lastWindowMean = null;
    _movingVotes = 0;
    _stationaryVotes = 0;
    readingNotifier.value = null;
    // "No disponible" se mantiene: el dispositivo no tiene sensor.
    if (state != MotionState.unavailable) {
      stateNotifier.value = MotionState.unknown;
    }
  }

  void _markUnavailable() {
    _subscription = null;
    readingNotifier.value = null;
    stateNotifier.value = MotionState.unavailable;
  }

  // Se ejecuta por cada muestra (~5 por segundo). El cálculo es barato (raíz
  // cuadrada y un promedio), no justifica un isolate.
  void _onEvent(AccelerometerEvent e) {
    final magnitude = math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
    final deviation = (magnitude - gravity).abs();
    _window.add(deviation);

    if (_window.length >= windowSize) {
      final mean = _window.reduce((a, b) => a + b) / _window.length;
      _window.clear();
      _lastWindowMean = mean;

      if (mean > movingThreshold) {
        _movingVotes++;
        _stationaryVotes = 0;
      } else if (mean < stationaryThreshold) {
        _stationaryVotes++;
        _movingVotes = 0;
      }

      if (_movingVotes >= windowsToMove) {
        if (stateNotifier.value != MotionState.moving) {
          debugPrint('Accelerometer: MOVING');
        }
        stateNotifier.value = MotionState.moving;
      } else if (_stationaryVotes >= windowsToStop) {
        if (stateNotifier.value != MotionState.stationary) {
          debugPrint('Accelerometer: STATIONARY');
        }
        stateNotifier.value = MotionState.stationary;
      }
    }

    readingNotifier.value = MotionReading(
      x: e.x,
      y: e.y,
      z: e.z,
      deviation: deviation,
      windowMean: _lastWindowMean,
      at: DateTime.now(),
    );
  }
}
