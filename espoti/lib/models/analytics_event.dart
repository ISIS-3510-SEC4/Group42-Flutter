enum AnalyticsEventType {
  recommendationRequested('RECOMMENDATION_REQUESTED'),
  recommendationDisplayed('RECOMMENDATION_DISPLAYED'),
  recommendationViewed('RECOMMENDATION_VIEWED'),
  recommendationSelected('RECOMMENDATION_SELECTED'),
  planningStepStarted('PLANNING_STEP_STARTED'),
  planningStepCompleted('PLANNING_STEP_COMPLETED'),
  planningFlowAbandoned('PLANNING_FLOW_ABANDONED'),
  featureUsed('FEATURE_USED'),
  filterUsed('FILTER_USED'),
  meetingCreated('MEETING_CREATED');

  const AnalyticsEventType(this.wireName);

  /// Name stored in Firestore, shared with the Kotlin app.
  final String wireName;
}

/// Same shape as the Kotlin AnalyticsEvent so both apps write to one collection.
class AnalyticsEvent {
  final String id;
  final AnalyticsEventType eventType;
  final String userId;
  final DateTime timestamp;
  final String sessionId;
  final String platform;
  final String? meetingId;
  final String? placeId;
  final String? step;
  final int? durationMs;
  final Map<String, Object?> metadata;

  const AnalyticsEvent({
    required this.id,
    required this.eventType,
    required this.userId,
    required this.timestamp,
    required this.sessionId,
    this.platform = 'FLUTTER',
    this.meetingId,
    this.placeId,
    this.step,
    this.durationMs,
    this.metadata = const {},
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'eventType': eventType.wireName,
        'userId': userId,
        'timestamp': timestamp,
        'sessionId': sessionId,
        'platform': platform,
        'meetingId': meetingId,
        'placeId': placeId,
        'step': step,
        'durationMs': durationMs,
        'metadata': metadata,
      };
}
