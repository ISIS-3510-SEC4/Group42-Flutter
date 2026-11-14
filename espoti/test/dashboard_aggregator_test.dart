import 'package:espoti/core/analytics/dashboard_aggregator.dart';
import 'package:flutter_test/flutter_test.dart';

// Pruebas del cálculo de las BQ que hace el tablero dentro de la app.
void main() {
  Map<String, dynamic> planning(String type, String attempt, String step,
          {Map<String, dynamic> extra = const {}}) =>
      {
        'eventType': type,
        'step': step,
        'metadata': {'attemptId': attempt, ...extra},
      };

  test('abandonment: counts attempts by their end and the step reached', () {
    final result = aggregatePlanningAbandonment([
      // a1: llega al paso 2 y abandona ahí
      planning('PLANNING_STEP_STARTED', 'a1', 'details'),
      planning('PLANNING_STEP_STARTED', 'a1', 'vote'),
      planning('PLANNING_FLOW_ABANDONED', 'a1', 'vote',
          extra: {'reason': 'navigation', 'maxStepIndex': 2}),
      // a2: completado
      planning('PLANNING_STEP_STARTED', 'a2', 'details'),
      planning('PLANNING_FLOW_COMPLETED', 'a2', 'result', extra: {'maxStepIndex': 3}),
      // a3: en curso (sin evento final)
      planning('PLANNING_STEP_STARTED', 'a3', 'details'),
    ]);
    expect(result['sampleCount'], 2);
    expect(result['completedAttempts'], 1);
    expect(result['abandonedAttempts'], 1);
    expect(result['openAttempts'], 1);
    final byStep = result['byStep'] as Map;
    expect((byStep['vote'] as Map)['abandoned'], 1);
    expect((byStep['vote'] as Map)['reached'], 2);
    expect((byStep['vote'] as Map)['abandonRate'], 0.5);
    expect((result['peakAbandonStep'] as Map)['step'], 'vote');
    expect((result['abandonReasons'] as Map)['navigation'], 1);
  });

  test('peaks: one event per meeting, grouped by transit mode', () {
    Map<String, dynamic> created(String id, String mode, String day, String window) => {
          'eventType': 'MEETING_CREATED',
          'meetingId': id,
          'metadata': {
            'transitMode': mode,
            'createdDayOfWeek': day,
            'createdTimeWindow': window,
          },
        };
    final result = aggregateMeetingPeakWindows([
      created('m1', 'WALK', 'MONDAY', 'MORNING'),
      created('m1', 'WALK', 'MONDAY', 'MORNING'), // duplicado
      created('m2', 'WALK', 'MONDAY', 'EVENING'),
      created('m3', 'CAR', 'FRIDAY', 'EVENING'),
    ]);
    expect(result['sampleCount'], 3);
    expect(result['ignoredEvents'], 1);
    final walk = (result['byTransitMode'] as Map)['WALK'] as Map;
    expect(walk['total'], 2);
    final peaks = (result['peaks'] as Map)['WALK'] as Map;
    expect((peaks['peakCreatedDay'] as Map)['key'], 'MONDAY');
  });

  test('no events: empty results instead of errors', () {
    final result = aggregateDashboard(const []);
    expect((result['planningAbandonment'] as Map)['sampleCount'], 0);
    expect((result['meetingPeakWindows'] as Map)['sampleCount'], 0);
  });
}
