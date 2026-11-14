import 'package:espoti/core/analytics/analytics_repository.dart';
import 'package:espoti/core/offline/pending_operation.dart';
import 'package:espoti/models/analytics_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('queues analytics events for offline synchronization', () async {
    PendingOperation? queued;
    final repository = FirestoreAnalyticsRepository(
      enqueue: (operation) async => queued = operation,
    );
    final timestamp = DateTime.utc(2026, 11, 14);
    final event = AnalyticsEvent(
      id: 'decision-1',
      eventType: AnalyticsEventType.recommendationDecision,
      userId: 'user-1',
      timestamp: timestamp,
      sessionId: 'session-1',
      metadata: {'accepted': true},
    );

    await repository.saveEvent(event);

    expect(queued, isNotNull);
    expect(queued!.kind, PendingWriteKind.createOnce);
    expect(queued!.collection, 'analytics_events');
    expect(queued!.docId, event.id);
    expect(queued!.ownerUid, event.userId);
    expect(
      queued!.data['timestamp'],
      PendingOperation.timestamp(timestamp),
    );
    expect(queued!.data['metadata'], {'accepted': true});
  });
}
