import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

import '../../models/analytics_event.dart';
import 'analytics_event_factory.dart';
import 'analytics_repository.dart';

/// Records recommendation events for one list of recommendations.
/// Used to answer: how many recommendations do users view before selecting one?
class RecommendationReviewTracker {
  RecommendationReviewTracker({
    AnalyticsRepository? repository,
    AnalyticsEventFactory? factory,
    String? Function()? currentUserId,
  })  : _repository = repository ?? FirestoreAnalyticsRepository(),
        _factory = factory ??
            AnalyticsEventFactory(sessionId: const Uuid().v4()),
        _currentUserId =
            currentUserId ?? (() => FirebaseAuth.instance.currentUser?.uid);

  final AnalyticsRepository _repository;
  final AnalyticsEventFactory _factory;
  final String? Function() _currentUserId;

  String _requestId = const Uuid().v4();
  final Set<String> _viewedPlaceIds = {};

  int get viewedCount => _viewedPlaceIds.length;

  /// Starts a new review: a fresh list was shown to the user.
  void displayed({required int resultCount, String? meetingId}) {
    _requestId = const Uuid().v4();
    _viewedPlaceIds.clear();
    final userId = _currentUserId();
    if (userId == null || resultCount <= 0) return;
    _save(_factory.recommendationDisplayed(
      userId,
      requestId: _requestId,
      resultCount: resultCount,
      meetingId: meetingId,
    ));
  }

  /// Counts each place once, no matter how many times it is opened.
  void viewed(String placeId, {String? meetingId}) {
    final userId = _currentUserId();
    if (userId == null || !_viewedPlaceIds.add(placeId)) return;
    _save(_factory.recommendationViewed(
      userId,
      requestId: _requestId,
      placeId: placeId,
      meetingId: meetingId,
    ));
  }

  void selected(String placeId, {String? meetingId}) {
    final userId = _currentUserId();
    if (userId == null) return;
    // The place being voted counts as reviewed even if it was never opened.
    viewed(placeId, meetingId: meetingId);
    _save(_factory.recommendationSelected(
      userId,
      requestId: _requestId,
      placeId: placeId,
      viewedCount: viewedCount,
      meetingId: meetingId,
    ));
  }

  // Analytics must never break the UI.
  void _save(AnalyticsEvent event) {
    _repository.saveEvent(event).catchError((Object error) {
      debugPrint('Analytics event not stored: $error');
    });
  }
}
