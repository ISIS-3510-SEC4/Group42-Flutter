/// Last known GPS position of a participant in a meeting.
class ParticipantLocation {
  final String userId;
  final String name;
  final double latitude;
  final double longitude;
  final DateTime updatedAt;

  /// Según el acelerómetro de ese participante, se estaba moviendo cuando
  /// envió esta posición (false si no se sabe).
  final bool moving;

  const ParticipantLocation({
    required this.userId,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.updatedAt,
    this.moving = false,
  });
}
