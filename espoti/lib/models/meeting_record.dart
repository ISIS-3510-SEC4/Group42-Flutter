import 'meeting.dart';
import 'meeting_vote.dart';
import 'transit_mode.dart';

/// A person invited to a meeting, stored inside the meeting document.
///
/// The app has no mechanism to send invitations (no e-mail or push backend),
/// so [status] is [notSent]: the invitation is registered, not delivered.
/// The e-mail is what Firestore rules use to let an invitee read the meeting.
class MeetingInvitee {
  final String name;
  final String email;
  final String status;

  /// Google People resource name (e.g. `people/c123`), so the contact picker
  /// recognizes the invitee again when the meeting is edited.
  final String? contactId;

  static const String notSent = 'not_sent';

  const MeetingInvitee({
    required this.name,
    required this.email,
    this.status = notSent,
    this.contactId,
  });

  String get displayName => name.isNotEmpty ? name : email;

  /// Lower-cased e-mail, the form used by the security rules.
  String get normalizedEmail => email.trim().toLowerCase();

  Map<String, dynamic> toJson() => {
        'name': name,
        'email': normalizedEmail,
        'status': status,
        if (contactId != null) 'contactId': contactId,
      };

  static MeetingInvitee? tryFromMap(Object? map) {
    if (map is! Map) return null;
    final name = map['name'];
    final email = map['email'];
    if (name is! String && email is! String) return null;
    return MeetingInvitee(
      name: name is String ? name : '',
      email: email is String ? email : '',
      status: map['status'] as String? ?? notSent,
      contactId: map['contactId'] as String?,
    );
  }
}

/// A meeting created by the user and persisted in Firestore (`meetings/{id}`).
///
/// `Meeting` (models/meeting.dart) stays as the lightweight view model used by
/// the recommendation cards; this class is the stored entity.
class MeetingRecord {
  /// Generated on the device (uuid v4) so offline creation and retries
  /// always target the same Firestore document (no duplicates).
  final String id;
  final String organizerId;
  final String activity;
  final String dayLabel;
  final String timeLabel;
  final DateTime? scheduledAt;
  final TransitMode? transitMode;
  final int? budgetPerPerson;
  final List<String> inviteeNames;

  /// Invitees with e-mail (from Google Contacts). Older meetings only have
  /// [inviteeNames]; for them this list is empty.
  final List<MeetingInvitee> invitees;

  /// Point picked on the map to search places around (not a live location).
  final double? pointLat;
  final double? pointLng;

  final String? placeName;
  final String? placeCategory;

  /// Lugares sobre los que votan los participantes (vacío si no hubo
  /// votación, por ejemplo una reunión sin invitados).
  final List<MeetingCandidate> candidates;

  /// Estados: planning -> pending_votes -> scheduled, o canceled.
  ///  - planning: creada en el paso 1, todavía sin lugar.
  ///  - pending_votes: el organizador ya votó y faltan invitados por votar.
  ///  - scheduled: lugar definido (votación cerrada o reunión sin invitados).
  final String status;
  final int createdAtClient;
  final int updatedAtClient;

  static const String planning = 'planning';
  static const String pendingVotes = 'pending_votes';
  static const String scheduled = 'scheduled';
  static const String canceled = 'canceled';

  /// Live location is shared only around the meeting time: from
  /// [locationWindowBefore] before [scheduledAt] until [locationWindowAfter]
  /// after it. The same window is enforced in firestore.rules.
  static const Duration locationWindowBefore = Duration(hours: 2);
  static const Duration locationWindowAfter = Duration(hours: 4);

  /// "Cerca de la hora de la reunión": desde 1 h antes hasta 15 min después.
  /// Si un participante se mueve en ese rango, probablemente ya va en camino.
  static const Duration onTheWayBefore = Duration(hours: 1);
  static const Duration onTheWayAfter = Duration(minutes: 15);

  const MeetingRecord({
    required this.id,
    required this.organizerId,
    required this.activity,
    required this.dayLabel,
    required this.timeLabel,
    this.scheduledAt,
    this.transitMode,
    this.budgetPerPerson,
    this.inviteeNames = const [],
    this.invitees = const [],
    this.pointLat,
    this.pointLng,
    this.placeName,
    this.placeCategory,
    this.candidates = const [],
    this.status = planning,
    required this.createdAtClient,
    required this.updatedAtClient,
  });

  MeetingRecord copyWith({
    String? activity,
    String? dayLabel,
    String? timeLabel,
    DateTime? scheduledAt,
    bool clearScheduledAt = false,
    TransitMode? transitMode,
    int? budgetPerPerson,
    bool clearBudget = false,
    List<String>? inviteeNames,
    List<MeetingInvitee>? invitees,
    double? pointLat,
    double? pointLng,
    String? placeName,
    String? placeCategory,
    List<MeetingCandidate>? candidates,
    String? status,
    int? updatedAtClient,
  }) =>
      MeetingRecord(
        id: id,
        organizerId: organizerId,
        activity: activity ?? this.activity,
        dayLabel: dayLabel ?? this.dayLabel,
        timeLabel: timeLabel ?? this.timeLabel,
        scheduledAt: clearScheduledAt ? null : (scheduledAt ?? this.scheduledAt),
        transitMode: transitMode ?? this.transitMode,
        budgetPerPerson: clearBudget ? null : (budgetPerPerson ?? this.budgetPerPerson),
        inviteeNames: inviteeNames ?? this.inviteeNames,
        invitees: invitees ?? this.invitees,
        pointLat: pointLat ?? this.pointLat,
        pointLng: pointLng ?? this.pointLng,
        placeName: placeName ?? this.placeName,
        placeCategory: placeCategory ?? this.placeCategory,
        candidates: candidates ?? this.candidates,
        status: status ?? this.status,
        createdAtClient: createdAtClient,
        updatedAtClient: updatedAtClient ?? this.updatedAtClient,
      );

  /// Upcoming / previous / canceled, for the Meetings tabs.
  MeetingStatus uiStatus(DateTime now) {
    if (status == canceled) return MeetingStatus.canceled;
    final at = scheduledAt;
    if (at != null && at.isBefore(now)) return MeetingStatus.previous;
    return MeetingStatus.upcoming;
  }

  String get title =>
      (placeName != null && placeName!.isNotEmpty) ? placeName! : activity;

  String get whenLabel => '$dayLabel $timeLabel'.trim();

  /// La votación sigue abierta: aún faltan participantes por votar.
  bool get isVotingOpen => status == pendingVotes;

  /// Lower-cased e-mails of the invitees (used by Firestore rules).
  List<String> get inviteeEmails => [
        for (final i in invitees)
          if (i.normalizedEmail.isNotEmpty) i.normalizedEmail,
      ];

  /// Organizer, or an invitee whose e-mail matches [email].
  bool isParticipant(String uid, String? email) {
    if (organizerId == uid) return true;
    final normalized = email?.trim().toLowerCase() ?? '';
    return normalized.isNotEmpty && inviteeEmails.contains(normalized);
  }

  /// [now] está cerca de la hora de la reunión (ver [onTheWayBefore]).
  bool isNearMeetingTime(DateTime now) {
    final at = scheduledAt;
    if (status == canceled || at == null) return false;
    return !now.isBefore(at.subtract(onTheWayBefore)) &&
        now.isBefore(at.add(onTheWayAfter));
  }

  /// Whether live location may be shared for this meeting at [now].
  bool isInLocationWindow(DateTime now) {
    final at = scheduledAt;
    if (status == canceled || at == null) return false;
    return !now.isBefore(at.subtract(locationWindowBefore)) &&
        now.isBefore(at.add(locationWindowAfter));
  }

  /// Local JSON (and outbox payload). Dates as epoch millis.
  Map<String, dynamic> toJson() => {
        'id': id,
        'organizerId': organizerId,
        'activity': activity,
        'dayLabel': dayLabel,
        'timeLabel': timeLabel,
        'scheduledAt': scheduledAt?.millisecondsSinceEpoch,
        'transitMode': transitMode?.wireName,
        'budgetPerPerson': budgetPerPerson,
        'inviteeNames': inviteeNames,
        'inviteesCount': inviteeNames.length,
        'invitees': invitees.map((i) => i.toJson()).toList(),
        'inviteeEmails': inviteeEmails,
        'meetingPoint': pointLat == null || pointLng == null
            ? null
            : {'lat': pointLat, 'lng': pointLng},
        'placeName': placeName,
        'placeCategory': placeCategory,
        'candidates': candidates.map((c) => c.toJson()).toList(),
        'status': status,
        'createdAtClient': createdAtClient,
        'clientUpdatedAt': updatedAtClient,
      };

  /// Reads local JSON or a Firestore map whose dates were already converted
  /// to epoch millis (see MeetingRepository).
  static MeetingRecord? tryFromMap(Map<String, dynamic> map) {
    final id = map['id'];
    final organizerId = map['organizerId'];
    if (id is! String || organizerId is! String) return null;
    final point = map['meetingPoint'];
    final scheduled = map['scheduledAt'];
    final names = map['inviteeNames'];
    final inviteesRaw = map['invitees'];
    final candidatesRaw = map['candidates'];
    return MeetingRecord(
      id: id,
      organizerId: organizerId,
      activity: map['activity'] as String? ?? '',
      dayLabel: map['dayLabel'] as String? ?? '',
      timeLabel: map['timeLabel'] as String? ?? '',
      scheduledAt:
          scheduled is int ? DateTime.fromMillisecondsSinceEpoch(scheduled) : null,
      transitMode: TransitMode.fromWire(map['transitMode']),
      budgetPerPerson: (map['budgetPerPerson'] as num?)?.toInt(),
      inviteeNames:
          names is List ? names.map((e) => e.toString()).toList() : const [],
      invitees: inviteesRaw is List
          ? inviteesRaw
              .map(MeetingInvitee.tryFromMap)
              .whereType<MeetingInvitee>()
              .toList()
          : const [],
      pointLat: point is Map ? (point['lat'] as num?)?.toDouble() : null,
      pointLng: point is Map ? (point['lng'] as num?)?.toDouble() : null,
      placeName: map['placeName'] as String?,
      placeCategory: map['placeCategory'] as String?,
      candidates: candidatesRaw is List
          ? candidatesRaw
              .map(MeetingCandidate.tryFromMap)
              .whereType<MeetingCandidate>()
              .toList()
          : const [],
      status: map['status'] as String? ?? planning,
      createdAtClient: (map['createdAtClient'] as num?)?.toInt() ?? 0,
      updatedAtClient: (map['clientUpdatedAt'] as num?)?.toInt() ?? 0,
    );
  }
}
