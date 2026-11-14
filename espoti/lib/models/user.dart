/// User model used across the Espoti application.
class AppUser {
  final String firstName;
  final String lastName;
  final String phone;
  final String name;
  final String code;
  final String location;
  final List<String> preferences;
  final int maxRadiusKm;
  final String avatarUrl;
  final String email;
  final String description;

  const AppUser({
    this.firstName = '',
    this.lastName = '',
    this.phone = '',
    required this.name,
    required this.code,
    required this.location,
    required this.preferences,
    required this.maxRadiusKm,
    this.avatarUrl = '',
    required this.email,
    required this.description,
  });

  /// Returns a copy of [AppUser] with updated fields.
  AppUser copyWith({
    String? firstName,
    String? lastName,
    String? name,
    String? code,
    String? location,
    List<String>? preferences,
    int? maxRadiusKm,
    String? avatarUrl,
    String? phone,
    String? email,
    String? description,
  }) {
    final newFirstName = firstName ?? this.firstName;
    final newLastName = lastName ?? this.lastName;
    String newFullName = name ?? this.name;
    if (name == null && (firstName != null || lastName != null)) {
      newFullName = '$newFirstName $newLastName'.trim();
      if (newFullName.isEmpty) newFullName = this.name;
    }

    return AppUser(
      firstName: newFirstName,
      lastName: newLastName,
      name: newFullName,
      code: code ?? this.code,
      location: location ?? this.location,
      preferences: preferences ?? this.preferences,
      maxRadiusKm: maxRadiusKm ?? this.maxRadiusKm,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      email: email ?? this.email,
      description: description ?? this.description,
      phone: phone ?? this.phone,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'name': name,
      'code': code,
      'location': location,
      'preferences': preferences,
      'maxRadiusKm': maxRadiusKm,
      'avatarUrl': avatarUrl,
      'email': email,
      'description': description,
      'phone': phone,
    };
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final fName = json['firstName'] as String? ?? '';
    final lName = json['lastName'] as String? ?? '';
    final defaultName = '$fName $lName'.trim();

    return AppUser(
      firstName: fName,
      lastName: lName,
      name: (json['name'] as String?)?.isNotEmpty == true
          ? json['name'] as String
          : defaultName,
      // Missing fields stay empty: no invented name, code, city or photo.
      code: json['code'] as String? ?? '',
      location: json['location'] as String? ?? '',
      preferences: (json['preferences'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      maxRadiusKm: (json['maxRadiusKm'] as num?)?.toInt() ?? 10,
      avatarUrl: json['avatarUrl'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      description: json['description'] as String? ?? '',
    );
  }
}

/// Profile shown while there is no signed-in user (e.g. right after
/// sign-out). Empty on purpose: no sample person is ever displayed.
const AppUser emptyUser = AppUser(
  name: '',
  code: '',
  location: '',
  preferences: [],
  maxRadiusKm: 10,
  email: '',
  description: '',
);
