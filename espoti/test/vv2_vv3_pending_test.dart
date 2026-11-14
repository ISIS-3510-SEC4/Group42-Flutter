import 'package:flutter_test/flutter_test.dart';
import 'package:espoti/core/services/activity_context_service.dart';
import 'package:espoti/core/services/analytics_service.dart';
import 'package:espoti/core/services/location_sharing_service.dart';
import 'package:espoti/features/meetings/location_sync_widgets.dart';
import 'package:espoti/models/meeting_record.dart';
import 'package:espoti/models/user.dart';

MeetingRecord _meeting({
  DateTime? scheduledAt,
  String status = MeetingRecord.planning,
  List<MeetingInvitee> invitees = const [],
}) =>
    MeetingRecord(
      id: 'm1',
      organizerId: 'organizer',
      activity: 'Eat',
      dayLabel: '2026-11-20',
      timeLabel: '2:00 pm',
      scheduledAt: scheduledAt,
      status: status,
      inviteeNames: invitees.map((i) => i.displayName).toList(),
      invitees: invitees,
      createdAtClient: 1,
      updatedAtClient: 1,
    );

void main() {
  group('Invitations (VV2-6)', () {
    test('invitees keep e-mail, status and contact id through JSON', () {
      final original = _meeting(invitees: const [
        MeetingInvitee(name: 'Ana', email: 'Ana@Example.com', contactId: 'people/c1'),
      ]);
      final json = original.toJson();
      expect(json['inviteeEmails'], ['ana@example.com']);

      final restored = MeetingRecord.tryFromMap(json)!;
      expect(restored.invitees.single.email, 'ana@example.com');
      expect(restored.invitees.single.status, MeetingInvitee.notSent);
      expect(restored.invitees.single.contactId, 'people/c1');
      expect(restored.inviteeNames, ['Ana']);
    });

    test('older meetings without invitees still load', () {
      final json = _meeting().toJson()
        ..remove('invitees')
        ..remove('inviteeEmails')
        ..['inviteeNames'] = ['Luis'];
      final restored = MeetingRecord.tryFromMap(json)!;
      expect(restored.invitees, isEmpty);
      expect(restored.inviteeNames, ['Luis']);
    });

    test('participants: organizer or invited e-mail (case-insensitive)', () {
      final m = _meeting(invitees: const [
        MeetingInvitee(name: 'Ana', email: 'ana@example.com'),
      ]);
      expect(m.isParticipant('organizer', null), isTrue);
      expect(m.isParticipant('other', 'ANA@example.com'), isTrue);
      expect(m.isParticipant('other', 'x@example.com'), isFalse);
      expect(m.isParticipant('other', null), isFalse);
    });
  });

  group('Location window (VV2-5)', () {
    final at = DateTime(2026, 11, 20, 14);

    test('inside the window around the scheduled time', () {
      final m = _meeting(scheduledAt: at);
      expect(m.isInLocationWindow(at.subtract(const Duration(hours: 2))), isTrue);
      expect(m.isInLocationWindow(at.add(const Duration(hours: 3))), isTrue);
    });

    test('outside the window, canceled or without date', () {
      expect(_meeting(scheduledAt: at)
          .isInLocationWindow(at.subtract(const Duration(hours: 3))), isFalse);
      expect(_meeting(scheduledAt: at)
          .isInLocationWindow(at.add(const Duration(hours: 4))), isFalse);
      expect(_meeting(scheduledAt: at, status: MeetingRecord.canceled)
          .isInLocationWindow(at), isFalse);
      expect(_meeting().isInLocationWindow(at), isFalse);
    });
  });

  group('On the way notice', () {
    final at = DateTime(2026, 11, 20, 14);
    test('near the meeting time: from 1 h before to 15 min after', () {
      final m = _meeting(scheduledAt: at);
      expect(m.isNearMeetingTime(at.subtract(const Duration(minutes: 59))), isTrue);
      expect(m.isNearMeetingTime(at.add(const Duration(minutes: 10))), isTrue);
      expect(m.isNearMeetingTime(at.subtract(const Duration(hours: 2))), isFalse);
      expect(m.isNearMeetingTime(at.add(const Duration(minutes: 20))), isFalse);
    });
  });

  group('Accelerometer indicator (VV2-4)', () {
    test('unknown motion is shown as detecting, never as stationary', () {
      final (_, label) = MotionStatusIndicator.describe(MotionState.unknown);
      expect(label, isNot(contains('Still')));
      expect(LocationSyncStatusLine.message(LocationSyncStatus.detecting),
          isNot(contains('Still')));
      final (_, stationary) =
          MotionStatusIndicator.describe(MotionState.stationary);
      expect(stationary, 'Still');
    });
  });

  group('Planning funnel (VV2-1)', () {
    test('open attempt survives a JSON round trip', () {
      const attempt = PlanningAttempt(
        id: 'a1',
        userId: 'u1',
        startedAt: 10,
        updatedAt: 20,
        currentStep: MeetingPlanningStep.vote,
        maxStepIndex: 2,
        meetingId: 'm1',
      );
      final restored = PlanningAttempt.tryFromJson(attempt.toJson())!;
      expect(restored.id, 'a1');
      expect(restored.userId, 'u1');
      expect(restored.currentStep, MeetingPlanningStep.vote);
      expect(restored.maxStepIndex, 2);
      expect(restored.meetingId, 'm1');
      expect(PlanningAttempt.tryFromJson('bad'), isNull);
    });

    test('going back from vote returns to details', () {
      expect(MeetingPlanningStep.previous(MeetingPlanningStep.vote),
          MeetingPlanningStep.details);
    });

    test('no open attempt: abandonment is ignored (edit mode)', () {
      expect(AnalyticsService().hasOpenAttempt, isFalse);
      AnalyticsService().stepAbandoned(MeetingPlanningStep.details);
      expect(AnalyticsService().hasOpenAttempt, isFalse);
    });
  });

  test('profile without session has no sample data', () {
    expect(emptyUser.name, isEmpty);
    expect(emptyUser.email, isEmpty);
    expect(AppUser.fromJson(const {}).location, isEmpty);
  });
}
