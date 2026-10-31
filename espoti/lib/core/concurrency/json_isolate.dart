
import 'dart:convert';
import 'package:flutter/foundation.dart';


class JsonIsolate {
  
  JsonIsolate._();

  // Define el tamaño mínimo (16 KB) para considerar que un JSON
  // necesita procesarse en un isolate.
  static const int isolateThreshold = 16 * 1024;

  // Método asíncrono que convierte un String JSON en un objeto Dart.
  static Future<Object?> decode(String source) async {
    
    if (source.isEmpty) return null;

    // Si la aplicación corre en Web o el JSON es pequeño,
    // lo decodifica directamente en el hilo principal.
    if (kIsWeb || source.length < isolateThreshold) {
      return jsonDecode(source);
    }

    // Si el JSON es grande, delega la decodificación a un isolate
    // mediante compute para evitar bloquear el hilo de la interfaz.
    return compute(_decode, source, debugLabel: 'espoti-json-decode');
  }

  // Método asíncrono que convierte un objeto Dart en un String JSON.
  static Future<String> encode(Object? value) async {
   
    if (!kIsWeb && _isLarge(value)) {
      return compute(_encode, value, debugLabel: 'espoti-json-encode');
    }

    return jsonEncode(value);
  }

  // Método privado que determina si un objeto es suficientemente grande
  // como para justificar su procesamiento en un isolate.
  static bool _isLarge(Object? value) {

    if (value is Map) {
      return value.length > 50 || _hasLargeChild(value.values);
    }

    if (value is List) {
      return value.length > 50;
    }

    return false;
  }

  // Método privado que revisa si alguno de los valores de un Map
  // contiene otra colección grande.
  static bool _hasLargeChild(Iterable<Object?> values) =>

      values.any((v) =>
          (v is Map && v.length > 50) ||
          (v is List && v.length > 50));
}

// Funciones externas a la clase ya que compute necesita funciones de nivel superior
// para poder ejecutarlas dentro de un isolate.

// Recibe un String JSON y lo convierte en un objeto Dart.
Object? _decode(String source) => jsonDecode(source);

// Recibe un objeto Dart y lo convierte en un String JSON.
String _encode(Object? value) => jsonEncode(value);