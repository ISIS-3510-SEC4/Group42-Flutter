import 'package:cloud_firestore/cloud_firestore.dart';

class MeetingPlanningTimeSnapshot {
  const MeetingPlanningTimeSnapshot({
    required this.summary,
    required this.fromCache,
  });

  final MeetingPlanningTimeSummary summary;
  final bool fromCache;
}

class MeetingPlanningTimeSummary {
  const MeetingPlanningTimeSummary({
    required this.averageMsByStep,
    required this.samplesByStep,
  });

  static const List<String> steps = ['details', 'vote', 'result'];

  final Map<String, int> averageMsByStep;
  final Map<String, int> samplesByStep;

  bool get hasData =>
      samplesByStep.values.any((sampleCount) => sampleCount > 0);

  List<String> get longestSteps {
    final measured = steps.where((step) => (samplesByStep[step] ?? 0) > 0);
    if (measured.isEmpty) return const [];
    final longest = measured
        .map((step) => averageMsByStep[step] ?? 0)
        .reduce((a, b) => a > b ? a : b);
    return [
      for (final step in measured)
        if (averageMsByStep[step] == longest) step,
    ];
  }
}

class MeetingPlanningTimeService {
  MeetingPlanningTimeService({FirebaseFirestore? firestore})
      : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  CollectionReference<Map<String, dynamic>> get _events =>
      (_firestore ?? FirebaseFirestore.instance).collection('analytics_events');

  Stream<MeetingPlanningTimeSnapshot> watchForUser(String userId) {
    if (userId.trim().isEmpty) {
      return Stream.error(ArgumentError.value(userId, 'userId'));
    }

    return _events
        .where('userId', isEqualTo: userId)
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) => MeetingPlanningTimeSnapshot(
              summary: aggregate(snapshot.docs.map((doc) => doc.data())),
              fromCache: snapshot.metadata.isFromCache,
            ));
  }

  static MeetingPlanningTimeSummary aggregate(
      Iterable<Map<String, dynamic>> events) {
    final totals = {
      for (final step in MeetingPlanningTimeSummary.steps) step: 0
    };
    final counts = {
      for (final step in MeetingPlanningTimeSummary.steps) step: 0
    };

    for (final event in events) {
      final step = event['step'];
      final duration = event['durationMs'];
      if (event['platform'] != 'FLUTTER' ||
          event['eventType'] != 'PLANNING_STEP_COMPLETED' ||
          step is! String ||
          !totals.containsKey(step) ||
          duration is! num ||
          duration < 0) {
        continue;
      }

      totals[step] = totals[step]! + duration.toInt();
      counts[step] = counts[step]! + 1;
    }

    return MeetingPlanningTimeSummary(
      averageMsByStep: {
        for (final step in MeetingPlanningTimeSummary.steps)
          step: counts[step] == 0 ? 0 : (totals[step]! / counts[step]!).round(),
      },
      samplesByStep: counts,
    );
  }
}
