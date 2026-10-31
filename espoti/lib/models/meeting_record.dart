import 'meeting.dart';
import 'transit_mode.dart';

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

  /// Point picked on the map to search places around (not a live location).
  final double? pointLat;
  final double? pointLng;

  final String? placeName;
  final String? placeCategory;
  final String status; // planning | scheduled | canceled
  final int createdAtClient;
  final int updatedAtClient;

  static const String planning = 'planning';
  static const String scheduled = 'scheduled';
  static const String canceled = 'canceled';

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
    this.pointLat,
    this.pointLng,
    this.placeName,
    this.placeCategory,
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
    double? pointLat,
    double? pointLng,
    String? placeName,
    String? placeCategory,
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
        pointLat: pointLat ?? this.pointLat,
        pointLng: pointLng ?? this.pointLng,
        placeName: placeName ?? this.placeName,
        placeCategory: placeCategory ?? this.placeCategory,
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
        'meetingPoint': pointLat == null || pointLng == null
            ? null
            : {'lat': pointLat, 'lng': pointLng},
        'placeName': placeName,
        'placeCategory': placeCategory,
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
      pointLat: point is Map ? (point['lat'] as num?)?.toDouble() : null,
      pointLng: point is Map ? (point['lng'] as num?)?.toDouble() : null,
      placeName: map['placeName'] as String?,
      placeCategory: map['placeCategory'] as String?,
      status: map['status'] as String? ?? planning,
      createdAtClient: (map['createdAtClient'] as num?)?.toInt() ?? 0,
      updatedAtClient: (map['clientUpdatedAt'] as num?)?.toInt() ?? 0,
    );
  }
}
