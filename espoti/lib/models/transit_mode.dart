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
