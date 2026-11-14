/// Límites de caracteres de los campos de texto de la app.
///
/// Se definen en un solo lugar para que la interfaz (maxLength del TextField,
/// contador y aviso de límite) y la validación al enviar el formulario usen
/// exactamente los mismos valores.
class InputLimits {
  InputLimits._();

  static const int firstName = 40;
  static const int lastName = 40;
  static const int email = 100;
  static const int passwordMin = 6;
  static const int passwordMax = 64;
  static const int phoneMin = 7;
  static const int phoneMax = 15;
  static const int activity = 50;
  static const int address = 120;
  static const int friendCode = 12;
  static const int description = 200;
  static const int contactSearch = 60;

  /// Mensaje de validación cuando un texto supera [max] caracteres.
  /// Devuelve null si el texto respeta el límite.
  static String? tooLong(String value, int max, String field) =>
      value.length > max ? '$field must be at most $max characters' : null;
}
