import 'package:espoti/core/analytics/meeting_creation_tracker.dart';
import 'package:espoti/core/cache/timed_cache.dart';
import 'package:espoti/core/offline/pending_operation.dart';
import 'package:espoti/models/meeting_record.dart';
import 'package:espoti/models/transit_mode.dart';
import 'package:flutter_test/flutter_test.dart';

PendingOperation _op(String docId, Map<String, dynamic> data,
        {PendingWriteKind kind = PendingWriteKind.upsert, int at = 1}) =>
    PendingOperation(
      id: 'op-$docId-$at',
      kind: kind,
      collection: 'meetings',
      docId: docId,
      ownerUid: 'u1',
      data: data,
      clientUpdatedAt: at,
    );

MeetingRecord _meeting({DateTime? scheduledAt}) => MeetingRecord(
      id: 'm1',
      organizerId: 'u1',
      activity: 'Eat',
      dayLabel: 'Sunday',
      timeLabel: '2:00 pm',
      scheduledAt: scheduledAt,
      transitMode: TransitMode.publicTransit,
      inviteeNames: const ['Ana', 'Luis'],
      pointLat: 4.6,
      pointLng: -74.08,
      createdAtClient: 10,
      updatedAtClient: 10,
    );

void main() {
  group('Outbox coalescing', () {
    test('a second upsert of the same document is merged, not duplicated', () {
      var queue = <PendingOperation>[];
      queue = PendingOperation.coalesce(queue, _op('m1', {'a': 1, 'b': 1}, at: 1));
      queue = PendingOperation.coalesce(queue, _op('m2', {'a': 9}, at: 2));
      queue = PendingOperation.coalesce(queue, _op('m1', {'b': 2}, at: 3));

      expect(queue, hasLength(2));
      expect(queue.first.docId, 'm1'); // keeps its original position
      expect(queue.first.data, {'a': 1, 'b': 2});
      expect(queue.first.clientUpdatedAt, 3);
    });

    test('createOnce for an already queued document is ignored', () {
      var queue = <PendingOperation>[];
      final first = _op('e1', {'x': 1}, kind: PendingWriteKind.createOnce);
      queue = PendingOperation.coalesce(queue, first);
      queue = PendingOperation.coalesce(
          queue, _op('e1', {'x': 2}, kind: PendingWriteKind.createOnce, at: 2));
      expect(queue, hasLength(1));
      expect(queue.single.data, {'x': 1});
    });

    test('operations survive a JSON round trip (persistence)', () {
      final op = _op('m1', {'when': PendingOperation.timestamp(DateTime(2026, 1, 1))});
      final restored = PendingOperation.tryFromJson(op.toJson());
      expect(restored, isNotNull);
      expect(restored!.path, 'meetings/m1');
      expect(PendingOperation.isTimestamp(restored.data['when']), isTrue);
    });
  });

  group('MeetingRecord', () {
    test('local JSON round trip keeps every field', () {
      final original = _meeting(scheduledAt: DateTime(2026, 11, 1, 14));
      final copy = MeetingRecord.tryFromMap(original.toJson())!;
      expect(copy.id, original.id);
      expect(copy.transitMode, TransitMode.publicTransit);
      expect(copy.scheduledAt, original.scheduledAt);
      expect(copy.inviteeNames, ['Ana', 'Luis']);
      expect(copy.pointLat, 4.6);
    });
  });

  group('Business question type 4 metadata', () {
    test('time windows', () {
      expect(MeetingTimeWindow.of(6), MeetingTimeWindow.earlyMorning);
      expect(MeetingTimeWindow.of(13), MeetingTimeWindow.midday);
      expect(MeetingTimeWindow.of(19), MeetingTimeWindow.evening);
      expect(MeetingTimeWindow.of(23), MeetingTimeWindow.night);
      expect(MeetingTimeWindow.of(2), MeetingTimeWindow.night);
    });

    test('metadata has day, window and transit mode but no coordinates', () {
      final meeting = _meeting(scheduledAt: DateTime(2026, 11, 1, 14)); // Sunday
      final metadata =
          MeetingCreationTracker.buildMetadata(meeting, DateTime(2026, 10, 30, 9));
      expect(metadata['transitMode'], 'PUBLIC_TRANSIT');
      expect(metadata['createdDayOfWeek'], 'FRIDAY');
      expect(metadata['createdTimeWindow'], 'MORNING');
      expect(metadata['scheduledDayOfWeek'], 'SUNDAY');
      expect(metadata['scheduledTimeWindow'], 'AFTERNOON');
      expect(metadata['groupSize'], 3);
      expect(metadata.keys.any((k) => k.toLowerCase().contains('lat')), isFalse);
    });
  });

  group('TimedCache', () {
    test('expires after the TTL and can be invalidated', () {
      var now = DateTime(2026, 1, 1, 10);
      final cache = TimedCache<int>(ttl: const Duration(minutes: 5), clock: () => now);
      cache.put('u1', 1);
      expect(cache.get('u1'), 1);
      expect(cache.get('u2'), isNull); // other user
      now = now.add(const Duration(minutes: 6));
      expect(cache.get('u1'), isNull);
      expect(cache.peek('u1'), 1); // stale fallback still available
      cache.put('u1', 2);
      cache.invalidate();
      expect(cache.get('u1'), isNull);
    });
  });
}
