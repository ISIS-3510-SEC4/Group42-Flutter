import 'dart:async';
import 'dart:io' show InternetAddress, SocketException;
import 'package:flutter/foundation.dart';

// Servicio encargado de comprobar si el dispositivo puede alcanzar
// realmente el servidor de Firebase.
class ConnectivityService {

  ConnectivityService._();

  // Implementa el patrón Singleton
  static final ConnectivityService instance = ConnectivityService._();

  // Define el dominio de Firestore al que se realizará la consulta DNS.
  static const String _probeHost = 'firestore.googleapis.com';

  // Define el tiempo máximo de espera para comprobar la conectividad.
  static const Duration _timeout = Duration(seconds: 4);

  // Almacena el último estado conocido de la conexión.
  final ValueNotifier<bool> isOnline = ValueNotifier<bool>(true);

  // Almacena una consulta de conectividad que todavía está ejecutándose.
  Future<bool>? _inFlight;

  // Método público que comprueba la conectividad.
  // Si ya existe una consulta en ejecución, devuelve esa misma consulta.
  // Si no existe, inicia una nueva mediante _probe().
  // Cuando termina, libera _inFlight para permitir futuras consultas.
  Future<bool> check() =>
      _inFlight ??= _probe().whenComplete(() => _inFlight = null);


  Future<bool> _probe() async {
    if (kIsWeb) return _set(true);


    try {

      // Realiza una consulta DNS al servidor de Firestore.
      final result = await InternetAddress.lookup(_probeHost).timeout(_timeout);

      // Comprueba que la consulta haya devuelto al menos una dirección IP
      return _set(result.isNotEmpty && result.first.rawAddress.isNotEmpty);

    } on SocketException {
      return _set(false);
    } on TimeoutException {

      return _set(false);

    } catch (_) {

      return _set(false);
    }
  }

  // Actualiza el estado de conectividad y devuelve el nuevo estado.
  bool _set(bool online) {

    if (isOnline.value != online) isOnline.value = online;

    return online;
  }
  void reportNetworkFailure() => _set(false);
}