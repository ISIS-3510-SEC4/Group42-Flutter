/// Mock user model used to populate the Profile screen.
class AppUser {
  final String name;
  final String code;
  final String location;
  final List<String> preferences;
  final int maxRadiusKm;
  final String avatarUrl;

  const AppUser({
    required this.name,
    required this.code,
    required this.location,
    required this.preferences,
    required this.maxRadiusKm,
    this.avatarUrl = '',
  });
}

/// Hardcoded mock user — no backend/auth involved in this sprint
const AppUser mockUser = AppUser(
  name: 'Julian',
  code: 'AXBZ12',
  location: 'Bogotá D.C.',
  preferences: ['Walk', 'Eat'],
  maxRadiusKm: 10,
  avatarUrl: 'https://i.pravatar.cc/200?img=13',
);
