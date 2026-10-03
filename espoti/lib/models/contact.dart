/// A Google contact that can be invited to a meeting.
class GoogleContact {
  final String id; // People API resourceName, e.g. "people/c123"
  final String name;
  final String email;
  final String photoUrl;

  const GoogleContact({
    required this.id,
    required this.name,
    required this.email,
    this.photoUrl = '',
  });

  String get displayName => name.isNotEmpty ? name : email;
}
