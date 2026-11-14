import '../../models/analytics_event.dart';
import '../offline/pending_operation.dart';
import '../offline/sync_queue.dart';

abstract class AnalyticsRepository {
  Future<void> saveEvent(AnalyticsEvent event);
}

typedef AnalyticsEventEnqueue = Future<void> Function(
  PendingOperation operation,
);

class FirestoreAnalyticsRepository implements AnalyticsRepository {
  FirestoreAnalyticsRepository({AnalyticsEventEnqueue? enqueue})
      : _enqueue = enqueue;

  final AnalyticsEventEnqueue? _enqueue;

  @override
  Future<void> saveEvent(AnalyticsEvent event) {
    final data = Map<String, dynamic>.from(event.toMap())
      ..['timestamp'] = PendingOperation.timestamp(event.timestamp);
    final operation = PendingOperation.create(
      kind: PendingWriteKind.createOnce,
      collection: 'analytics_events',
      docId: event.id,
      ownerUid: event.userId,
      data: data,
      now: event.timestamp,
    );
    return (_enqueue ?? SyncQueue.instance.enqueue)(operation);
  }
}
