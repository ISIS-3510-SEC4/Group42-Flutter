import 'contact.dart';

/// Un amigo del usuario. Puede venir de dos fuentes:
///  - Google Contacts (nombre, correo y/o celular), o
///  - la búsqueda por código de Espoti (nombre, foto, código y uid).
class Friend {
  final String name;
  final String email;
  final String phone;
  final String photoUrl;

  /// Solo para amigos encontrados por código: su usuario de Espoti.
  final String? uid;
  final String? code;

  const Friend({
    required this.name,
    this.email = '',
    this.phone = '',
    this.photoUrl = '',
    this.uid,
    this.code,
  });

  factory Friend.fromContact(GoogleContact c) => Friend(
        name: c.name,
        email: c.email,
        phone: c.phone,
        photoUrl: c.photoUrl,
      );

  /// Clave para no repetir amigos: el usuario de Espoti, si no el correo,
  /// si no el celular (solo dígitos).
  String get key {
    if (uid != null && uid!.isNotEmpty) return 'uid:$uid';
    if (email.isNotEmpty) return 'email:${email.toLowerCase()}';
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return 'phone:$digits';
  }

  String get displayName => name.isNotEmpty
      ? name
      : (email.isNotEmpty ? email : (phone.isNotEmpty ? phone : (code ?? '')));

  /// Texto bajo el nombre en la lista.
  String get detail {
    if (code != null && code!.isNotEmpty) return 'Espoti code: $code';
    if (email.isNotEmpty) return email;
    return phone;
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'email': email,
        'phone': phone,
        'photoUrl': photoUrl,
        if (uid != null) 'uid': uid,
        if (code != null) 'code': code,
      };

  static Friend? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final friend = Friend(
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      photoUrl: json['photoUrl'] as String? ?? '',
      uid: json['uid'] as String?,
      code: json['code'] as String?,
    );
    // Sin ningún dato que lo identifique, no se carga.
    return friend.key == 'phone:' ? null : friend;
  }
}
