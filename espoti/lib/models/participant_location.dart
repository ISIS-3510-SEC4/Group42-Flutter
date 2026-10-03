/// Last known GPS position of a participant in a meeting.
class ParticipantLocation {
  final String userId;
  final String name;
  final double latitude;
  final double longitude;
  final DateTime updatedAt;

  const ParticipantLocation({
    required this.userId,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.updatedAt,
  });
}
