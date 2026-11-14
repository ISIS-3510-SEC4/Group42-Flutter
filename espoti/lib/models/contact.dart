/// A Google contact that can be invited to a meeting or imported as a friend.
///
/// Un contacto se acepta si tiene correo **o** celular (antes solo se
/// aceptaban los que tenían correo). Para la votación de reuniones solo
/// cuentan los invitados con correo, porque así se les reconoce en la app.
class GoogleContact {
  final String id; // People API resourceName, e.g. "people/c123"
  final String name;
  final String email;

  /// Primer número de teléfono del contacto (vacío si no tiene).
  final String phone;
  final String photoUrl;

  const GoogleContact({
    required this.id,
    required this.name,
    required this.email,
    this.phone = '',
    this.photoUrl = '',
  });

  bool get hasEmail => email.isNotEmpty;

  String get displayName =>
      name.isNotEmpty ? name : (email.isNotEmpty ? email : phone);

  /// Correo o, si no tiene, el teléfono (para mostrar bajo el nombre).
  String get detail => email.isNotEmpty ? email : phone;
}
