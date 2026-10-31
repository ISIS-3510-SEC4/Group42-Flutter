
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../concurrency/json_isolate.dart';

// Clase encargada de guardar, consultar y eliminar datos localmente.
// Forma parte de la capa de persistencia del sistema offline-first.
class LocalStore {

  LocalStore._();

  // Crea una única instancia de LocalStore para toda la aplicación.
  // Esto implementa el patrón Singleton.
  static final LocalStore instance = LocalStore._();

  // Define la clave donde se almacenan las operaciones pendientes de sincronización.
  static const String outboxKey = 'espoti_sync_outbox_v1';

  // Define la clave donde se almacenan las operaciones que fallaron durante el proceso de sincronización.

  static const String deadLetterKey = 'espoti_sync_failed_v1';

  // Genera una clave única para guardar el perfil de un usuario. El UID permite diferenciar los datos de cada usuario.
  static String userProfileKey(String uid) => 'espoti_user_profile_$uid';

  // Genera una clave única para guardar la fecha de la última consulta de información del usuario.
  static String userFetchedAtKey(String uid) => 'espoti_user_fetched_at_$uid';

  // Genera una clave única para guardar la copia local de las reuniones pertenecientes a un usuario.
  static String meetingsKey(String uid) => 'espoti_meetings_v1_$uid';

  // Obtiene una instancia de SharedPreferences de manera asíncrona.
  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  // Método asíncrono que recibe una clave y recupera su contenido JSON.
  Future<Object?> readJson(String key) async {

    try {

      // Obtiene SharedPreferences y recupera el String almacenado
      final raw = (await _prefs).getString(key);

      if (raw == null || raw.isEmpty) return null;

      // Convierte el String JSON en un objeto Dart.
      // Utiliza JsonIsolate para decidir si procesa los datos
      // en el hilo principal o en un isolate.
      return await JsonIsolate.decode(raw);

    } catch (e) {

      debugPrint('LocalStore: cannot read $key: $e');

      return null;
    }
  }

  // Método asíncrono que recibe una clave y un objeto Dart
  // para almacenarlo localmente en formato JSON.
  Future<void> writeJson(String key, Object? value) async {

    // Convierte el objeto Dart en un String JSON.
    // Si el objeto es grande, JsonIsolate utiliza un isolate.
    final encoded = await JsonIsolate.encode(value);

    // Obtiene SharedPreferences y guarda el JSON como String
    // asociado a la clave proporcionada.
    await (await _prefs).setString(key, encoded);
  }

  // Método asíncrono que recupera un número entero almacenado

  Future<int?> readInt(String key) async => (await _prefs).getInt(key);

  // Recibe la clave donde se guardará y el valor que se almacenará.
  Future<void> writeInt(String key, int value) async =>
      (await _prefs).setInt(key, value);

  // Método asíncrono que elimina de SharedPreferences
  // el dato asociado a la clave recibida.
  Future<void> remove(String key) async => (await _prefs).remove(key);
}