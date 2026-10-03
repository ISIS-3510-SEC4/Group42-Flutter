import 'package:flutter/foundation.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  FirebaseAnalytics? _analytics;

  FirebaseAnalytics get analytics {
    _analytics ??= FirebaseAnalytics.instance;
    return _analytics!;
  }

  Future<void> logStepTime({
    required String stepName,
    required int durationSeconds,
    Map<String, Object>? parameters,
  }) async {
    try {
      final params = <String, Object>{
        'step_name': stepName,
        'duration_seconds': durationSeconds,
        if (parameters != null) ...parameters,
      };

      await analytics.logEvent(
        name: 'step_duration',
        parameters: params,
      );

      debugPrint('Analytics [step_duration]: paso=$stepName, duracion=${durationSeconds}s');
    } catch (e) {
      debugPrint('Error enviando evento a Firebase Analytics: $e');
    }
  }
}
