import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../models/analytics_event.dart';
import 'analytics_repository.dart';

/// Interaction patterns that users perform before making a recommendation decision.
class RecommendationInteractionPattern {
  static const String directSelect = 'DIRECT_SELECT';
  static const String mapExpanded = 'MAP_EXPANDED';
  static const String detailsViewed = 'DETAILS_VIEWED';
  static const String budgetFiltered = 'BUDGET_FILTERED';
  static const String multipleViewed = 'MULTIPLE_VIEWED';
}

/// Tracker for Business Question Tipo 5:
/// "How do user's location preferences and interaction patterns affect the
/// acceptance rate of meeting point recommendations?"
class RecommendationAcceptanceTracker {
  RecommendationAcceptanceTracker({
    AnalyticsRepository? repository,
    String? sessionId,
  })  : _repository = repository ?? FirestoreAnalyticsRepository(),
        _sessionId = sessionId ?? const Uuid().v4();

  static final RecommendationAcceptanceTracker instance =
      RecommendationAcceptanceTracker();

  final AnalyticsRepository _repository;
  final String _sessionId;

  /// Records a user's decision (accepted or rejected) on a recommended meeting point,
  /// capturing their location preferences and interaction pattern.
  Future<void> recordDecision({
    required String userId,
    String? meetingId,
    required String placeId,
    required String placeName,
    required String placeCategory,
    required List<String> locationPreferences,
    required int maxRadiusKm,
    required double distanceMeters,
    required String interactionPattern,
    required bool accepted,
    int? durationMs,
    Map<String, Object?> extraMetadata = const {},
  }) async {
    final metadata = <String, Object?>{
      'placeName': placeName,
      'placeCategory': placeCategory,
      'locationPreferences': locationPreferences,
      'maxRadiusKm': maxRadiusKm,
      'distanceMeters': distanceMeters,
      'interactionPattern': interactionPattern,
      'accepted': accepted,
      ...extraMetadata,
    };

    final event = AnalyticsEvent(
      id: const Uuid().v4(),
      eventType: AnalyticsEventType.recommendationDecision,
      userId: userId,
      timestamp: DateTime.now(),
      sessionId: _sessionId,
      platform: 'FLUTTER',
      meetingId: meetingId,
      placeId: placeId,
      durationMs: durationMs,
      metadata: metadata,
    );

    try {
      await _repository.saveEvent(event);
      debugPrint(
        'BQ5 Analytics: Logged decision (accepted: $accepted, pattern: $interactionPattern, prefs: $locationPreferences)',
      );
    } catch (e) {
      debugPrint('BQ5 Analytics: Error logging event: $e');
    }
  }

  /// Convenience tracker for when a recommendation is accepted and confirmed.
  Future<void> recordAccepted({
    required String userId,
    String? meetingId,
    required String placeId,
    required String placeName,
    required String placeCategory,
    required List<String> locationPreferences,
    required int maxRadiusKm,
    required double distanceMeters,
    String interactionPattern = RecommendationInteractionPattern.directSelect,
    int? durationMs,
  }) =>
      recordDecision(
        userId: userId,
        meetingId: meetingId,
        placeId: placeId,
        placeName: placeName,
        placeCategory: placeCategory,
        locationPreferences: locationPreferences,
        maxRadiusKm: maxRadiusKm,
        distanceMeters: distanceMeters,
        interactionPattern: interactionPattern,
        accepted: true,
        durationMs: durationMs,
      );

  /// Convenience tracker for when a recommendation is rejected, skipped, or discarded.
  Future<void> recordRejected({
    required String userId,
    String? meetingId,
    required String placeId,
    required String placeName,
    required String placeCategory,
    required List<String> locationPreferences,
    required int maxRadiusKm,
    required double distanceMeters,
    String interactionPattern = RecommendationInteractionPattern.directSelect,
    int? durationMs,
  }) =>
      recordDecision(
        userId: userId,
        meetingId: meetingId,
        placeId: placeId,
        placeName: placeName,
        placeCategory: placeCategory,
        locationPreferences: locationPreferences,
        maxRadiusKm: maxRadiusKm,
        distanceMeters: distanceMeters,
        interactionPattern: interactionPattern,
        accepted: false,
        durationMs: durationMs,
      );
}
