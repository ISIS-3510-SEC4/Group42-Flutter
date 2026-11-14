// Opciones: transporte público, carro, caminando y bicicleta. En Firestore y en
// el JSON local se guarda wireName (PUBLIC_TRANSIT…); en la tabla SQLite
// meetings se guarda el name del enum (publicTransit…). Cada lectura usa el
// mismo formato con el que se escribió, pero son dos formatos distintos.
/// How the group plans to get to a meeting (business question type 4).
enum TransitMode {
  publicTransit('PUBLIC_TRANSIT', 'Public transit'),
  driving('DRIVING', 'Driving'),
  walking('WALKING', 'Walking'),
  cycling('CYCLING', 'Bicycle');

  const TransitMode(this.wireName, this.label);

  /// Value stored in Firestore.
  final String wireName;

  /// Text shown in the UI.
  final String label;

  static TransitMode? fromWire(Object? value) {
    for (final mode in TransitMode.values) {
      if (mode.wireName == value) return mode;
    }
    return null;
  }
}
