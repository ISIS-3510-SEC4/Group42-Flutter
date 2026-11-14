// Implementa una caché en memoria con tiempo de expiración (TTL).

class TimedCache<T> {

  // Constructor que recibe obligatoriamente el tiempo de vida de la caché (ttl).
  // También permite recibir un reloj personalizado para controlar el tiempo.
  // Si no se proporciona un reloj, utiliza la fecha y hora actual del dispositivo.
  TimedCache({required this.ttl, DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;


  final Duration ttl;
  final DateTime Function() _clock;

  // Almacena la clave asociada al dato guardado en la caché.
  String? _key;

  // Almacena el valor guardado en la caché.
  T? _value;

  // Registra el momento en que se almacenó el dato.
  // Determina si la caché sigue vigente.
  DateTime? _storedAt;

  // Recupera el valor asociado a una clave

  T? get(String key) {


    if (_key != key || _storedAt == null) return null;

    // Calcula cuánto tiempo ha pasado desde que se guardaron los datos.
    // Si ese tiempo supera el TTL, considera que la caché expiró.
    if (_clock().difference(_storedAt!) > ttl) return null;

    return _value;
  }

  T? peek(String key) => _key == key ? _value : null;

  // Guarda un nuevo valor en la caché asociado a una clave.
  void put(String key, T value, {DateTime? storedAt}) {

    _key = key;
    _value = value;
    _storedAt = storedAt ?? _clock();
  }

  // Actualiza el valor almacenado sin modificar su fecha original.
  // Para realizar modificaciones locales sin hacer que los datos
  // parezcan más recientes de lo que realmente son.
  void update(String key, T value) {

    if (_key != key) return;
    _value = value;
  }

  // Comprueba si existe una caché vigente para la clave recibida.
  bool isFresh(String key) => get(key) != null;

  // Invalida la caché estableciendo su fecha de almacenamiento en null.
  // Hace que la siguiente consulta con get() devuelva null
  // y obliga a buscar información actualizada en Firestore.
  void invalidate() => _storedAt = null;

  void clear() {
    _key = null;
    _value = null;
    _storedAt = null;
  }
}