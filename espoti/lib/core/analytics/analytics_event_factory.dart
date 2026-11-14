import 'package:uuid/uuid.dart';

import '../../models/analytics_event.dart';

// Patrón Factory Method: todos los eventos se crean aquí con el mismo
// sessionId. El reloj (clock) y el generador de ids son inyectables para las
// pruebas.
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
    String? id,
  }) {
    return AnalyticsEvent(
      id: id ?? _idGenerator(),
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

  /// Business question type 1: one event per loaded list of recommendations,
  /// with the fallback data it used (empty when everything came live).
  AnalyticsEvent recommendationLoaded(
    String userId, {
    required List<String> fallbacks,
    String? meetingId,
  }) =>
      _create(
        AnalyticsEventType.recommendationLoaded,
        userId,
        meetingId: meetingId,
        metadata: {'fallbacks': fallbacks},
      );

  // BQ tipo 4 (VV3): id meeting_created_<meetingId> → un único evento por
  // reunión.
  /// Business question type 4. One event per meeting: the id is derived from
  /// the meeting id, so retries and edits never create a second event.
  AnalyticsEvent meetingCreated(
    String userId, {
    required String meetingId,
    required Map<String, Object?> metadata,
  }) =>
      _create(
        AnalyticsEventType.meetingCreated,
        userId,
        meetingId: meetingId,
        metadata: metadata,
        id: 'meeting_created_$meetingId',
      );

  // VV2: metadata.attemptId es la clave con la que planning_abandonment.js
  // agrupa los eventos por intento.
  /// Business question (VV2): planning funnel events. Every event carries the
  /// planning attempt id in `metadata.attemptId` so one attempt can be
  /// followed from its first step to its end (completed or abandoned).
  /// Pass [id] to make the event idempotent (e.g. one end event per attempt).
  AnalyticsEvent planningEvent(
    AnalyticsEventType type,
    String userId, {
    required String attemptId,
    required String step,
    String? meetingId,
    int? durationMs,
    Map<String, Object?> metadata = const {},
    String? id,
    DateTime? at,
  }) {
    final event = _create(
      type,
      userId,
      meetingId: meetingId,
      step: step,
      durationMs: durationMs,
      metadata: {'attemptId': attemptId, ...metadata},
      id: id,
    );
    if (at == null) return event;
    return AnalyticsEvent(
      id: event.id,
      eventType: event.eventType,
      userId: event.userId,
      timestamp: at,
      sessionId: event.sessionId,
      meetingId: event.meetingId,
      placeId: event.placeId,
      step: event.step,
      durationMs: event.durationMs,
      metadata: event.metadata,
    );
  }
}
