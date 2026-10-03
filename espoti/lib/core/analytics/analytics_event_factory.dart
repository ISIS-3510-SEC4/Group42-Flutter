import 'package:uuid/uuid.dart';

import '../../models/analytics_event.dart';

/// Factory Method: single place that builds every [AnalyticsEvent].
class AnalyticsEventFactory {
  AnalyticsEventFactory({
    required this.sessionId,
    DateTime Function()? clock,
    String Function()? idGenerator,
  })  : _clock = clock ?? DateTime.now,
        _idGenerator = idGenerator ?? (() => const Uuid().v4());

  final String sessionId;
  final DateTime Function() _clock;
  final String Function() _idGenerator;

  AnalyticsEvent _create(
    AnalyticsEventType type,
    String userId, {
    String? meetingId,
    String? placeId,
    String? step,
    int? durationMs,
    Map<String, Object?> metadata = const {},
  }) {
    return AnalyticsEvent(
      id: _idGenerator(),
      eventType: type,
      userId: userId,
      timestamp: _clock(),
      sessionId: sessionId,
      meetingId: meetingId,
      placeId: placeId,
      step: step,
      durationMs: durationMs,
      metadata: metadata,
    );
  }

  AnalyticsEvent recommendationDisplayed(
    String userId, {
    required String requestId,
    required int resultCount,
    String? meetingId,
  }) =>
      _create(
        AnalyticsEventType.recommendationDisplayed,
        userId,
        meetingId: meetingId,
        metadata: {'requestId': requestId, 'resultCount': resultCount},
      );

  AnalyticsEvent recommendationViewed(
    String userId, {
    required String requestId,
    required String placeId,
    String? meetingId,
  }) =>
      _create(
        AnalyticsEventType.recommendationViewed,
        userId,
        meetingId: meetingId,
        placeId: placeId,
        metadata: {'requestId': requestId},
      );

  AnalyticsEvent recommendationSelected(
    String userId, {
    required String requestId,
    required String placeId,
    required int viewedCount,
    String? meetingId,
  }) =>
      _create(
        AnalyticsEventType.recommendationSelected,
        userId,
        meetingId: meetingId,
        placeId: placeId,
        metadata: {'requestId': requestId, 'viewedCount': viewedCount},
      );
}
