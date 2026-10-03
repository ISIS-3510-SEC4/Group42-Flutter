/// User model used across the Espoti application.
class AppUser {
  final String firstName;
  final String lastName;
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
          : (defaultName.isNotEmpty ? defaultName : 'Julian'),
      code: json['code'] as String? ?? 'AXBZ12',
      location: json['location'] as String? ?? 'Bogotá D.C.',
      preferences: (json['preferences'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const ['Walk', 'Eat'],
      maxRadiusKm: json['maxRadiusKm'] as int? ?? 10,
      avatarUrl: json['avatarUrl'] as String? ?? 'https://i.pravatar.cc/200?img=13',
      email: json['email'] as String? ?? '',
      description: json['description'] as String? ?? '',
    );
  }
}

/// Default mock user fallback
const AppUser mockUser = AppUser(
  firstName: 'Julian',
  lastName: '',
  name: 'Julian',
  code: 'AXBZ12',
  location: 'Bogotá D.C.',
  preferences: ['Walk', 'Eat'],
  maxRadiusKm: 10,
  avatarUrl: 'https://i.pravatar.cc/200?img=13',
  email: 'sj****hk@gmail.com',
  description: '',
);
