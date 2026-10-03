import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Steps of the meeting planning flow, in order.
class MeetingPlanningStep {
  MeetingPlanningStep._();

  static const String details = 'details'; // CreateMeetingPage
  static const String vote = 'vote'; // VoteMeetingPage
  static const String result = 'result'; // WinningPlacePage

  static int indexOf(String step) => switch (step) {
        details => 1,
        vote => 2,
        result => 3,
        _ => 0,
      };
}

/// Thin wrapper over Firebase Analytics.
///
/// Business question: "At which step do users most frequently abandon the
/// meeting planning process?". Events (all carry `step` and `step_index`):
///  - meeting_planning_step_view
///  - meeting_planning_step_complete
///  - meeting_planning_abandon   <- count by `step` to find the friction point
///  - meeting_planning_completed
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  bool _flowCompleted = false;

  Future<void> _log(String name, Map<String, Object> params) async {
    try {
      await FirebaseAnalytics.instance.logEvent(name: name, parameters: params);
    } catch (e) {
      debugPrint('Analytics error ($name): $e');
    }
  }

  Map<String, Object> _stepParams(String step, [Map<String, Object>? extra]) =>
      {
        'step': step,
        'step_index': MeetingPlanningStep.indexOf(step),
        ...?extra,
      };

  /// Call when the first step opens, so a new planning attempt starts clean.
  void meetingPlanningStarted() => _flowCompleted = false;

  void stepViewed(String step, {Map<String, Object>? extra}) =>
      _log('meeting_planning_step_view', _stepParams(step, extra));

  void stepCompleted(String step, {Map<String, Object>? extra}) =>
      _log('meeting_planning_step_complete', _stepParams(step, extra));

  /// Call when the user leaves a step screen without moving forward.
  void stepAbandoned(String step, {Map<String, Object>? extra}) {
    if (_flowCompleted) return;
    _log('meeting_planning_abandon', _stepParams(step, extra));
  }

  void planningCompleted() {
    _flowCompleted = true;
    _log('meeting_planning_completed',
        _stepParams(MeetingPlanningStep.result));
  }
}
