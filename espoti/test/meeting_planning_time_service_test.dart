import 'package:espoti/features/analytics/meeting_planning_time_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('averages completed Flutter steps and finds the longest step', () {
    final summary = MeetingPlanningTimeService.aggregate([
      {
        'platform': 'FLUTTER',
        'eventType': 'PLANNING_STEP_COMPLETED',
        'step': 'details',
        'durationMs': 10000,
      },
      {
        'platform': 'FLUTTER',
        'eventType': 'PLANNING_STEP_COMPLETED',
        'step': 'details',
        'durationMs': 30000,
      },
      {
        'platform': 'FLUTTER',
        'eventType': 'PLANNING_STEP_COMPLETED',
        'step': 'vote',
        'durationMs': 55000,
      },
      {
        'platform': 'FLUTTER',
        'eventType': 'PLANNING_STEP_COMPLETED',
        'step': 'result',
        'durationMs': 40000,
      },
      {
        'platform': 'FLUTTER',
        'eventType': 'PLANNING_STEP_STARTED',
        'step': 'vote',
        'durationMs': 90000,
      },
      {
        'platform': 'KOTLIN',
        'eventType': 'PLANNING_STEP_COMPLETED',
        'step': 'vote',
        'durationMs': 120000,
      },
    ]);

    expect(summary.averageMsByStep, {
      'details': 20000,
      'vote': 55000,
      'result': 40000,
    });
    expect(summary.samplesByStep, {'details': 2, 'vote': 1, 'result': 1});
    expect(summary.longestSteps, ['vote']);
  });
}
