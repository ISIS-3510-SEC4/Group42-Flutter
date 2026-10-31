import 'package:uuid/uuid.dart';

import '../../models/meeting_record.dart';
import '../offline/pending_operation.dart';
import '../offline/sync_service.dart';
import 'analytics_event_factory.dart';

/// Time windows used to group meetings (local device time).
enum MeetingTimeWindow {
  earlyMorning('EARLY_MORNING', 5, 8),
  morning('MORNING', 8, 12),
  midday('MIDDAY', 12, 14),
  afternoon('AFTERNOON', 14, 18),
  evening('EVENING', 18, 22),
  night('NIGHT', 22, 5);

  const MeetingTimeWindow(this.wireName, this.startHour, this.endHour);
  final String wireName;
  final int startHour; // inclusive
  final int endHour; // exclusive

  static MeetingTimeWindow of(int hour) {
    for (final w in values) {
      if (w.startHour < w.endHour && hour >= w.startHour && hour < w.endHour) {
        return w;
      }
    }
    return night;
  }
}

const _weekdayNames = [
  'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY',
];

/// Business question (type 4):
/// "What are the peak days and time windows during which groups organize
/// meetings, broken down by transit mode?"
///
/// Writes one MEETING_CREATED event to `analytics_events` per meeting, linked
/// to the meeting (`meetingId`) and its organizer (`userId`). It stores only
/// day/hour/window, transit mode and group size; no coordinates or addresses.
/// The event goes through the sync outbox, so meetings created offline are
/// counted once connectivity returns (with the original creation time).
class MeetingCreationTracker {
  MeetingCreationTracker({AnalyticsEventFactory? factory})
      : _factory = factory ?? AnalyticsEventFactory(sessionId: _sessionId);

  static final String _sessionId = const Uuid().v4();
  final AnalyticsEventFactory _factory;

  /// Pure: metadata for [meeting] created at [createdAt]. Exposed for tests.
  static Map<String, Object?> buildMetadata(
      MeetingRecord meeting, DateTime createdAt) {
    final scheduled = meeting.scheduledAt;
    return {
      'transitMode': meeting.transitMode?.wireName ?? 'UNSPECIFIED',
      // When the group organized it (moment of creation).
      'createdDayOfWeek': _weekdayNames[createdAt.weekday - 1],
      'createdHour': createdAt.hour,
      'createdTimeWindow': MeetingTimeWindow.of(createdAt.hour).wireName,
      // When the meeting will take place (null if the form text was unreadable).
      'scheduledDayOfWeek':
          scheduled == null ? null : _weekdayNames[scheduled.weekday - 1],
      'scheduledHour': scheduled?.hour,
      'scheduledTimeWindow':
          scheduled == null ? null : MeetingTimeWindow.of(scheduled.hour).wireName,
      'groupSize': meeting.inviteeNames.length + 1, // invitees + organizer
      'timezoneOffsetMinutes': createdAt.timeZoneOffset.inMinutes,
    };
  }

  /// Queues the event for [meeting]. Safe to call more than once.
  Future<void> meetingCreated(MeetingRecord meeting) async {
    final createdAt =
        DateTime.fromMillisecondsSinceEpoch(meeting.createdAtClient);
    final event = _factory.meetingCreated(
      meeting.organizerId,
      meetingId: meeting.id,
      metadata: buildMetadata(meeting, createdAt),
    );
    final data = Map<String, dynamic>.from(event.toMap())
      ..['timestamp'] = PendingOperation.timestamp(createdAt);

    await SyncService.instance.enqueue(PendingOperation.create(
      kind: PendingWriteKind.createOnce,
      collection: 'analytics_events',
      docId: event.id,
      ownerUid: meeting.organizerId,
      data: data,
    ));
  }
}
