
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

  const Meeting({
    required this.placeName,
    required this.timeLabel,
    required this.distanceLabel,
    this.avatarUrls = const [],
    this.extraParticipantsLabel = '',
    this.rating,
    this.imageUrl = '',
    this.status = MeetingStatus.upcoming,
  });
}

/// Mock data used across Home and Meetings screens.
class MockMeetings {
  MockMeetings._();

  static const List<Meeting> nextMeetings = [
    Meeting(
      placeName: 'Restaurant',
      timeLabel: '2:00 pm',
      distanceLabel: '2 km',
      avatarUrls: [
        'https://i.pravatar.cc/100?img=5',
        'https://i.pravatar.cc/100?img=12',
      ],
      extraParticipantsLabel: 'Ana and two more',
    ),
    Meeting(
      placeName: 'Park',
      timeLabel: '4:00 pm',
      distanceLabel: '3 km',
      avatarUrls: [
        'https://i.pravatar.cc/100?img=8',
        'https://i.pravatar.cc/100?img=15',
      ],
      extraParticipantsLabel: 'Julian and two more',
    ),
  ];

  static const List<Meeting> meetingsList = [
    Meeting(
      placeName: 'Restaurant Los Andes',
      timeLabel: '30 Minutes',
      distanceLabel: '3km from your location',
      avatarUrls: [
        'https://i.pravatar.cc/100?img=1',
        'https://i.pravatar.cc/100?img=2',
        'https://i.pravatar.cc/100?img=3',
      ],
      rating: 4,
      imageUrl: 'https://picsum.photos/seed/espoti1/300/200',
      status: MeetingStatus.upcoming,
    ),
    Meeting(
      placeName: 'Cafeteria Doña Blanca',
      timeLabel: '2 days',
      distanceLabel: '3km from your location',
      avatarUrls: [
        'https://i.pravatar.cc/100?img=9',
        'https://i.pravatar.cc/100?img=10',
        'https://i.pravatar.cc/100?img=11',
      ],
      rating: 4,
      imageUrl: 'https://picsum.photos/seed/espoti2/300/200',
      status: MeetingStatus.upcoming,
    ),
  ];
}
