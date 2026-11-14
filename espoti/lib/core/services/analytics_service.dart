import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../models/analytics_event.dart';
import '../analytics/analytics_event_factory.dart';
import '../offline/local_store.dart';
import '../offline/pending_operation.dart';
import '../offline/sync_service.dart';

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

  /// Step shown when the user goes back from [step].
  static String previous(String step) => switch (step) {
        result => vote,
        vote => details,
        _ => details,
      };
}

/// Why a planning attempt ended without a meeting being completed.
class PlanningAbandonReason {
  PlanningAbandonReason._();

  /// The user closed the first screen (back button or bottom navigation).
  static const String leftScreen = 'left_screen';

  /// The user left step 2 through the bottom navigation.
  static const String navigation = 'navigation';

  /// The app was closed or killed while the attempt was open; detected the
  /// next time the app starts.
  static const String appClosed = 'app_closed';

  /// A new attempt started while another one was still open.
  static const String restarted = 'restarted';
}

/// One planning attempt: from opening "Create a meeting" until the meeting is
/// completed (place chosen) or the attempt is abandoned. Persisted locally
/// while open so an attempt interrupted by closing the app is still counted.
@immutable
class PlanningAttempt {
  final String id;
  final String? userId;
  final int startedAt;
  final int updatedAt;
  final String currentStep;
  final int maxStepIndex;
  final String? meetingId;

  const PlanningAttempt({
    required this.id,
    required this.userId,
    required this.startedAt,
    required this.updatedAt,
    required this.currentStep,
    required this.maxStepIndex,
    this.meetingId,
  });

  PlanningAttempt copyWith({
    String? currentStep,
    int? maxStepIndex,
    String? meetingId,
    int? updatedAt,
  }) =>
      PlanningAttempt(
        id: id,
        userId: userId,
        startedAt: startedAt,
        updatedAt: updatedAt ?? this.updatedAt,
        currentStep: currentStep ?? this.currentStep,
        maxStepIndex: maxStepIndex ?? this.maxStepIndex,
        meetingId: meetingId ?? this.meetingId,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'startedAt': startedAt,
        'updatedAt': updatedAt,
        'currentStep': currentStep,
        'maxStepIndex': maxStepIndex,
        'meetingId': meetingId,
      };

  static PlanningAttempt? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final step = json['currentStep'];
    if (id is! String || step is! String) return null;
    return PlanningAttempt(
      id: id,
      userId: json['userId'] as String?,
      startedAt: (json['startedAt'] as num?)?.toInt() ?? 0,
      updatedAt: (json['updatedAt'] as num?)?.toInt() ?? 0,
      currentStep: step,
      maxStepIndex: (json['maxStepIndex'] as num?)?.toInt() ??
          MeetingPlanningStep.indexOf(step),
      meetingId: json['meetingId'] as String?,
    );
  }
}

/// Planning funnel analytics.
///
/// Business question (VV2): "At which step do users most frequently abandon
/// the meeting planning process?".
///
/// Every event is sent to Firebase Analytics (GA4) with `attempt_id`, and,
/// when there is a signed-in user, also written to Firestore
/// `analytics_events` through the offline outbox ([SyncService]), so it can be
/// aggregated (analytics/planning_abandonment.js) and shown in the app.
///
/// Firestore events (`metadata.attemptId` links them):
///  - PLANNING_STEP_STARTED     one per step view
///  - PLANNING_STEP_COMPLETED   one per step and attempt
///  - PLANNING_FLOW_ABANDONED   terminal, doc id `planning_<attempt>_end`
///  - PLANNING_FLOW_COMPLETED   terminal, same doc id, so an attempt has a
///                              single end event even with retries.
///
/// Editing an existing meeting is not a planning attempt: the screens do not
/// start an attempt in edit mode, and without an open attempt nothing is
/// recorded as abandoned.
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  static const String openAttemptKey = 'espoti_planning_open_attempt_v1';
  static final String _sessionId = const Uuid().v4();

  final AnalyticsEventFactory _factory =
      AnalyticsEventFactory(sessionId: _sessionId);

  PlanningAttempt? _attempt;
  DateTime? _stepViewedAt;

  /// Id of the planning attempt in progress, if any.
  String? get currentAttemptId => _attempt?.id;

  bool get hasOpenAttempt => _attempt != null;

  String? get _uid {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // GA4
  // ---------------------------------------------------------------------------

  Future<void> _log(String name, Map<String, Object> params) async {
    final attemptId = _attempt?.id;
    try {
      await FirebaseAnalytics.instance.logEvent(name: name, parameters: {
        ...params,
        if (attemptId != null && !params.containsKey('attempt_id'))
          'attempt_id': attemptId,
      });
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

  // ---------------------------------------------------------------------------
  // Funnel API used by the planning screens
  // ---------------------------------------------------------------------------

  /// Starts a new planning attempt. Call only when creating a new meeting
  /// (never in edit mode).
  void meetingPlanningStarted() {
    final previous = _attempt;
    if (previous != null) {
      _endAbandoned(previous,
          step: previous.currentStep, reason: PlanningAbandonReason.restarted);
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final uid = _uid;
    _attempt = PlanningAttempt(
      id: const Uuid().v4(),
      userId: uid,
      startedAt: now,
      updatedAt: now,
      currentStep: MeetingPlanningStep.details,
      maxStepIndex: MeetingPlanningStep.indexOf(MeetingPlanningStep.details),
    );
    if (uid != null) {
      unawaited(FirebaseAnalytics.instance
          .setUserId(id: uid)
          .catchError((Object e) => debugPrint('Analytics setUserId: $e')));
    }
    _log('meeting_planning_started', const {});
    _persistOpen();
  }

  void stepViewed(String step, {Map<String, Object>? extra}) {
    _log('meeting_planning_step_view', _stepParams(step, extra));
    final attempt = _attempt;
    if (attempt == null) return;
    _stepViewedAt = DateTime.now();
    final index = MeetingPlanningStep.indexOf(step);
    _attempt = attempt.copyWith(
      currentStep: step,
      maxStepIndex: index > attempt.maxStepIndex ? index : attempt.maxStepIndex,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    _record(AnalyticsEventType.planningStepStarted, step: step, extra: extra);
    _persistOpen();
  }

  void stepCompleted(String step,
      {Map<String, Object>? extra, String? meetingId}) {
    _log('meeting_planning_step_complete', _stepParams(step, extra));
    final attempt = _attempt;
    if (attempt == null) return;
    _attempt = attempt.copyWith(
      meetingId: meetingId,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    final viewedAt = _stepViewedAt;
    _record(
      AnalyticsEventType.planningStepCompleted,
      step: step,
      extra: extra,
      id: 'planning_${attempt.id}_complete_$step',
      durationMs: viewedAt == null
          ? null
          : DateTime.now().difference(viewedAt).inMilliseconds,
    );
    _persistOpen();
  }

  /// The user went back from [step] to the previous step: the attempt stays
  /// open. Ignored when no attempt is open.
  void stepLeftBackwards(String step) {
    final attempt = _attempt;
    if (attempt == null) return;
    _log('meeting_planning_step_back', _stepParams(step));
    _attempt = attempt.copyWith(
      currentStep: MeetingPlanningStep.previous(step),
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    _stepViewedAt = DateTime.now();
    _persistOpen();
  }

  /// The user left the flow at [step] without finishing. Ends the attempt.
  /// Ignored when no attempt is open (already completed, or edit mode).
  void stepAbandoned(String step,
      {Map<String, Object>? extra,
      String reason = PlanningAbandonReason.leftScreen}) {
    final attempt = _attempt;
    if (attempt == null) return;
    _endAbandoned(attempt, step: step, reason: reason, extra: extra);
  }

  void planningCompleted({String? meetingId}) {
    final attempt = _attempt;
    _log('meeting_planning_completed',
        _stepParams(MeetingPlanningStep.result));
    if (attempt == null) return;
    final now = DateTime.now();
    _record(
      AnalyticsEventType.planningFlowCompleted,
      step: MeetingPlanningStep.result,
      id: 'planning_${attempt.id}_end',
      meetingId: meetingId ?? attempt.meetingId,
      durationMs: now.millisecondsSinceEpoch - attempt.startedAt,
      extra: {'maxStepIndex': attempt.maxStepIndex},
    );
    _closeAttempt();
  }

  /// Time spent on one planning step (seconds).
  void logStepTime({required String stepName, required int durationSeconds}) =>
      _log('meeting_planning_step_time', {
        'step_name': stepName,
        'duration_seconds': durationSeconds,
      });

  /// At app start: an attempt that was still open when the app was closed or
  /// killed is recorded as abandoned at its last step.
  Future<void> recoverInterruptedAttempt() async {
    if (_attempt != null) return;
    try {
      final stored =
          PlanningAttempt.tryFromJson(await LocalStore.instance.readJson(openAttemptKey));
      if (stored == null) return;
      await LocalStore.instance.remove(openAttemptKey);
      _log('meeting_planning_abandon', {
        ..._stepParams(stored.currentStep),
        'attempt_id': stored.id,
        'reason': PlanningAbandonReason.appClosed,
      });
      _enqueue(
        stored,
        AnalyticsEventType.planningFlowAbandoned,
        step: stored.currentStep,
        id: 'planning_${stored.id}_end',
        at: DateTime.fromMillisecondsSinceEpoch(stored.updatedAt),
        durationMs: stored.updatedAt - stored.startedAt,
        extra: {
          'reason': PlanningAbandonReason.appClosed,
          'stepIndex': MeetingPlanningStep.indexOf(stored.currentStep),
          'maxStepIndex': stored.maxStepIndex,
        },
      );
    } catch (e) {
      debugPrint('Planning attempt not recovered: $e');
    }
  }

  // ---------------------------------------------------------------------------

  void _endAbandoned(PlanningAttempt attempt,
      {required String step,
      required String reason,
      Map<String, Object>? extra}) {
    _log('meeting_planning_abandon', {
      ..._stepParams(step, extra),
      'attempt_id': attempt.id,
      'reason': reason,
    });
    _enqueue(
      attempt,
      AnalyticsEventType.planningFlowAbandoned,
      step: step,
      id: 'planning_${attempt.id}_end',
      durationMs: DateTime.now().millisecondsSinceEpoch - attempt.startedAt,
      extra: {
        ...?extra,
        'reason': reason,
        'maxStepIndex': attempt.maxStepIndex,
      },
    );
    _closeAttempt();
  }

  void _closeAttempt() {
    _attempt = null;
    _stepViewedAt = null;
    unawaited(LocalStore.instance
        .remove(openAttemptKey)
        .catchError((Object e) => debugPrint('Planning attempt not cleared: $e')));
  }

  void _persistOpen() {
    final attempt = _attempt;
    if (attempt == null) return;
    unawaited(LocalStore.instance
        .writeJson(openAttemptKey, attempt.toJson())
        .catchError((Object e) => debugPrint('Planning attempt not saved: $e')));
  }

  void _record(
    AnalyticsEventType type, {
    required String step,
    Map<String, Object>? extra,
    String? id,
    String? meetingId,
    int? durationMs,
  }) {
    final attempt = _attempt;
    if (attempt == null) return;
    _enqueue(
      attempt,
      type,
      step: step,
      id: id,
      meetingId: meetingId,
      durationMs: durationMs,
      extra: {'stepIndex': MeetingPlanningStep.indexOf(step), ...?extra},
    );
  }

  /// Writes the event through the outbox (works offline). Only for attempts
  /// with a signed-in user: the security rules require `userId == auth.uid`.
  void _enqueue(
    PlanningAttempt attempt,
    AnalyticsEventType type, {
    required String step,
    String? id,
    String? meetingId,
    int? durationMs,
    DateTime? at,
    Map<String, Object?> extra = const {},
  }) {
    final uid = attempt.userId;
    if (uid == null) return;
    final event = _factory.planningEvent(
      type,
      uid,
      attemptId: attempt.id,
      step: step,
      meetingId: meetingId ?? attempt.meetingId,
      durationMs: durationMs,
      metadata: extra,
      id: id,
      at: at,
    );
    final data = Map<String, dynamic>.from(event.toMap())
      ..['timestamp'] = PendingOperation.timestamp(event.timestamp);
    unawaited(SyncService.instance
        .enqueue(PendingOperation.create(
          kind: PendingWriteKind.createOnce,
          collection: 'analytics_events',
          docId: event.id,
          ownerUid: uid,
          data: data,
        ))
        .catchError((Object e) => debugPrint('Planning event not queued: $e')));
  }
}
