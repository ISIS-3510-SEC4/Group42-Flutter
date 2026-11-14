enum MeetingStatus { upcoming, previous, canceled }

class Meeting {
  final String placeName;
  final String timeLabel;
  final String distanceLabel;
  final List<String> avatarUrls;
  final String extraParticipantsLabel;
  final double? rating;
  final String imageUrl;
  final MeetingStatus status;

  /// Estimated cost per person (COP). Set by the budget recommendation.
  final int? estimatedCostPerPerson;

  const Meeting({
    required this.placeName,
    required this.timeLabel,
    required this.distanceLabel,
    this.avatarUrls = const [],
    this.extraParticipantsLabel = '',
    this.rating,
    this.imageUrl = '',
    this.status = MeetingStatus.upcoming,
    this.estimatedCostPerPerson,
  });

  Meeting withEstimatedCost(int cost) => Meeting(
        placeName: placeName,
        timeLabel: timeLabel,
        distanceLabel: distanceLabel,
        avatarUrls: avatarUrls,
        extraParticipantsLabel: extraParticipantsLabel,
        rating: rating,
        imageUrl: imageUrl,
        status: status,
        estimatedCostPerPerson: cost,
      );
}
