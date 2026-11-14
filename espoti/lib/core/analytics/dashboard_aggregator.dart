/// Agregación de las BQ dentro de la app (lógica pura, sin Firebase).
///
/// El tablero lee los eventos crudos de Firestore (`analytics_events`, la
/// única base de datos) y aquí se calculan los resultados. Antes esto lo
/// hacían scripts de Node que había que correr a mano; ahora el cálculo
/// ocurre en el mismo tablero, en tiempo real, cada vez que llegan eventos.
///
/// Las funciones reciben mapas "planos" (los Timestamp ya convertidos a
/// milisegundos) para poder ejecutarse en un isolate con `compute`.
library;

/// Tipos de evento que necesita el tablero.
const List<String> dashboardEventTypes = [
  'PLANNING_STEP_STARTED',
  'PLANNING_STEP_COMPLETED',
  'PLANNING_FLOW_ABANDONED',
  'PLANNING_FLOW_COMPLETED',
  'MEETING_CREATED',
];

const List<String> planningSteps = ['details', 'vote', 'result'];
const Map<String, int> _stepIndex = {'details': 1, 'vote': 2, 'result': 3};

const List<String> weekDays = [
  'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY',
];
const List<String> timeWindows = [
  'EARLY_MORNING', 'MORNING', 'MIDDAY', 'AFTERNOON', 'EVENING', 'NIGHT',
];

/// Calcula las dos BQ a partir de los mismos eventos. Es la función que se
/// manda al isolate (debe ser de nivel superior).
Map<String, dynamic> aggregateDashboard(List<Map<String, dynamic>> events) => {
      'planningAbandonment': aggregatePlanningAbandonment(events),
      'meetingPeakWindows': aggregateMeetingPeakWindows(events),
      'eventCount': events.length,
    };

Map<String, dynamic> _meta(Map<String, dynamic> e) =>
    e['metadata'] is Map ? Map<String, dynamic>.from(e['metadata'] as Map) : const {};

int? _int(Object? v) => v is num ? v.toInt() : null;

// ---------------------------------------------------------------------------
// BQ (VV2): ¿en qué paso se abandona con más frecuencia la planificación?
// ---------------------------------------------------------------------------

/// Agrupa los eventos PLANNING_* por intento (`metadata.attemptId`).
///  - Un intento es "completado" si tiene PLANNING_FLOW_COMPLETED,
///    "abandonado" si tiene PLANNING_FLOW_ABANDONED (en el paso del evento) y
///    "en curso" si todavía no tiene evento final (no entra en las tasas).
///  - Por paso: cuántos intentos terminados llegaron, cuántos abandonaron ahí
///    y la tasa de abandono = abandonos / llegaron.
Map<String, dynamic> aggregatePlanningAbandonment(
    List<Map<String, dynamic>> events) {
  final attempts = <String, _Attempt>{};
  var ignored = 0;

  for (final e in events) {
    final type = e['eventType'];
    if (type is! String || !type.startsWith('PLANNING_')) continue;
    final m = _meta(e);
    final attemptId = m['attemptId'];
    final step = e['step'];
    if (attemptId is! String || step is! String || !planningSteps.contains(step)) {
      ignored++;
      continue;
    }
    final a = attempts.putIfAbsent(attemptId, _Attempt.new);
    final index = _int(m['stepIndex']) ?? _stepIndex[step] ?? 0;
    final maxIndex = _int(m['maxStepIndex']) ?? 0;
    if (index > a.maxStepIndex) a.maxStepIndex = index;
    if (maxIndex > a.maxStepIndex) a.maxStepIndex = maxIndex;
    if (type == 'PLANNING_FLOW_COMPLETED') {
      a.end = 'completed';
    } else if (type == 'PLANNING_FLOW_ABANDONED' && a.end != 'completed') {
      a.end = 'abandoned';
      a.abandonStep = step;
      a.reason = m['reason'] is String ? m['reason'] as String : 'unknown';
      a.durationMs = _int(e['durationMs']);
    }
  }

  final byStep = {
    for (final s in planningSteps)
      s: <String, dynamic>{
        'stepIndex': _stepIndex[s],
        'reached': 0,
        'abandoned': 0,
        'abandonRate': 0.0,
        'avgMsBeforeAbandon': null,
      },
  };
  final reasons = <String, int>{};
  final durations = <String, List<int>>{};
  var completed = 0, abandoned = 0, open = 0;

  for (final a in attempts.values) {
    if (a.end == null) {
      open++;
      continue;
    }
    for (final s in planningSteps) {
      if (a.maxStepIndex >= _stepIndex[s]!) {
        byStep[s]!['reached'] = (byStep[s]!['reached'] as int) + 1;
      }
    }
    if (a.end == 'completed') {
      completed++;
      continue;
    }
    abandoned++;
    final s = a.abandonStep!;
    byStep[s]!['abandoned'] = (byStep[s]!['abandoned'] as int) + 1;
    reasons[a.reason!] = (reasons[a.reason!] ?? 0) + 1;
    if (a.durationMs != null) (durations[s] ??= []).add(a.durationMs!);
  }

  Map<String, dynamic>? peak;
  for (final s in planningSteps) {
    final data = byStep[s]!;
    final reached = data['reached'] as int;
    final ab = data['abandoned'] as int;
    data['abandonRate'] = reached > 0 ? ab / reached : 0.0;
    final values = durations[s] ?? const <int>[];
    data['avgMsBeforeAbandon'] = values.isEmpty
        ? null
        : (values.reduce((x, y) => x + y) / values.length).round();
    if (ab > 0 && (peak == null || ab > (peak['abandoned'] as int))) {
      peak = {'step': s, 'abandoned': ab, 'abandonRate': data['abandonRate']};
    }
  }

  final finished = completed + abandoned;
  return {
    'sampleCount': finished,
    'completedAttempts': completed,
    'abandonedAttempts': abandoned,
    'openAttempts': open,
    'completionRate': finished > 0 ? completed / finished : 0.0,
    'ignoredEvents': ignored,
    'byStep': byStep,
    'abandonReasons': reasons,
    'peakAbandonStep': peak,
  };
}

class _Attempt {
  int maxStepIndex = 0;
  String? end;
  String? abandonStep;
  String? reason;
  int? durationMs;
}

// ---------------------------------------------------------------------------
// BQ tipo 5: aceptación de recomendaciones de lugares.
// ---------------------------------------------------------------------------

/// Aggregates explicit recommendation decisions by preference and interaction.
/// Events without a boolean `accepted` value are ignored so legacy selections
/// cannot be mistaken for a complete BQ5 decision.
Map<String, dynamic> aggregateRecommendationAcceptance(
    List<Map<String, dynamic>> events) {
  const question =
      "How do user's location preferences and interaction patterns affect the acceptance rate of meeting point recommendations?";
  final byPreference = <String, Map<String, int>>{};
  final byPattern = <String, Map<String, int>>{};
  final byCategory = <String, Map<String, int>>{};
  var totalDecisions = 0;
  var totalAccepted = 0;
  var totalRejected = 0;
  var ignoredEvents = 0;
  var acceptedDistanceSum = 0.0;
  var acceptedDistanceCount = 0;
  var rejectedDistanceSum = 0.0;
  var rejectedDistanceCount = 0;

  void record(Map<String, Map<String, int>> groups, String key, bool accepted) {
    final stats = groups.putIfAbsent(key, () => {'total': 0, 'accepted': 0});
    stats['total'] = stats['total']! + 1;
    if (accepted) stats['accepted'] = stats['accepted']! + 1;
  }

  for (final event in events) {
    if (event['eventType'] != 'RECOMMENDATION_DECISION') continue;
    final metadata = _meta(event);
    final accepted = metadata['accepted'];
    if (accepted is! bool) {
      ignoredEvents++;
      continue;
    }

    totalDecisions++;
    if (accepted) {
      totalAccepted++;
    } else {
      totalRejected++;
    }

    final preferences = metadata['locationPreferences'];
    if (preferences is List) {
      for (final value in preferences) {
        final preference = value.toString().trim();
        if (preference.isNotEmpty) {
          record(byPreference, preference, accepted);
        }
      }
    }

    final patternValue = metadata['interactionPattern'];
    final pattern = patternValue is String && patternValue.isNotEmpty
        ? patternValue
        : 'DIRECT_SELECT';
    record(byPattern, pattern, accepted);

    final categoryValue = metadata['placeCategory'];
    final category = categoryValue is String && categoryValue.isNotEmpty
        ? categoryValue
        : 'General';
    record(byCategory, category, accepted);

    final distance = metadata['distanceMeters'];
    if (distance is num && distance > 0) {
      if (accepted) {
        acceptedDistanceSum += distance.toDouble();
        acceptedDistanceCount++;
      } else {
        rejectedDistanceSum += distance.toDouble();
        rejectedDistanceCount++;
      }
    }
  }

  double rate(int accepted, int total) => total == 0
      ? 0
      : double.parse(((accepted / total) * 100).toStringAsFixed(1));

  Map<String, dynamic> formatGroups(Map<String, Map<String, int>> groups) => {
        for (final entry in groups.entries)
          entry.key: {
            'total': entry.value['total']!,
            'accepted': entry.value['accepted']!,
            'rate': rate(entry.value['accepted']!, entry.value['total']!),
          },
      };

  return {
    'question': question,
    'platform': 'FLUTTER',
    'totalDecisions': totalDecisions,
    'totalAccepted': totalAccepted,
    'totalRejected': totalRejected,
    'overallAcceptanceRate': rate(totalAccepted, totalDecisions),
    'byPreference': formatGroups(byPreference),
    'byInteractionPattern': formatGroups(byPattern),
    'byCategory': formatGroups(byCategory),
    'distanceMetrics': {
      'avgDistanceAcceptedMeters': acceptedDistanceCount == 0
          ? 0
          : (acceptedDistanceSum / acceptedDistanceCount).round(),
      'avgDistanceRejectedMeters': rejectedDistanceCount == 0
          ? 0
          : (rejectedDistanceSum / rejectedDistanceCount).round(),
    },
    'ignoredEvents': ignoredEvents,
  };
}

// ---------------------------------------------------------------------------
// BQ tipo 4 (VV3): días y franjas pico en que se organizan reuniones, por
// medio de transporte.
// ---------------------------------------------------------------------------

/// Cuenta los MEETING_CREATED (uno por reunión) por medio de transporte ×
/// día, × franja y × día-franja, tanto de creación como de la fecha
/// programada, y calcula el pico de cada uno.
Map<String, dynamic> aggregateMeetingPeakWindows(
    List<Map<String, dynamic>> events) {
  final seen = <String>{};
  final byMode = <String, Map<String, dynamic>>{};
  var ignored = 0;

  void inc(String mode, String group, [String? key]) {
    final node = byMode.putIfAbsent(mode, () => <String, dynamic>{});
    if (key == null) {
      node[group] = ((node[group] as int?) ?? 0) + 1;
      return;
    }
    final map = (node[group] as Map<String, int>?) ?? <String, int>{};
    map[key] = (map[key] ?? 0) + 1;
    node[group] = map;
  }

  for (final e in events) {
    if (e['eventType'] != 'MEETING_CREATED') continue;
    final m = _meta(e);
    final meetingId = e['meetingId'];
    final day = m['createdDayOfWeek'];
    final window = m['createdTimeWindow'];
    final mode = m['transitMode'];
    final valid = meetingId is String &&
        weekDays.contains(day) &&
        timeWindows.contains(window) &&
        mode is String;
    // Un evento por reunión (los ids ya son deterministas; esto es una guarda).
    if (!valid || !seen.add(meetingId)) {
      ignored++;
      continue;
    }
    inc(mode, 'total');
    inc(mode, 'createdByDay', day as String);
    inc(mode, 'createdByWindow', window as String);
    inc(mode, 'createdByDayAndWindow', '${day}_$window');
    final sDay = m['scheduledDayOfWeek'];
    final sWindow = m['scheduledTimeWindow'];
    if (weekDays.contains(sDay) && timeWindows.contains(sWindow)) {
      inc(mode, 'scheduledByDay', sDay as String);
      inc(mode, 'scheduledByWindow', sWindow as String);
    }
  }

  Map<String, dynamic>? peakOf(Object? counts) {
    if (counts is! Map<String, int>) return null;
    MapEntry<String, int>? best;
    for (final entry in counts.entries) {
      if (best == null || entry.value > best.value) best = entry;
    }
    return best == null ? null : {'key': best.key, 'count': best.value};
  }

  return {
    'sampleCount': seen.length,
    'ignoredEvents': ignored,
    'byTransitMode': byMode,
    'peaks': {
      for (final entry in byMode.entries)
        entry.key: {
          'peakCreatedDay': peakOf(entry.value['createdByDay']),
          'peakCreatedWindow': peakOf(entry.value['createdByWindow']),
          'peakCreatedDayAndWindow': peakOf(entry.value['createdByDayAndWindow']),
          'peakScheduledDay': peakOf(entry.value['scheduledByDay']),
          'peakScheduledWindow': peakOf(entry.value['scheduledByWindow']),
        },
    },
  };
}
