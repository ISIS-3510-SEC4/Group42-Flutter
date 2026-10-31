import 'dart:math' as math;

import 'package:latlong2/latlong.dart';
import '../../../core/concurrency/geo_isolate.dart';

class Participant {
  const Participant({required this.name, required this.location});

  final String name;
  final LatLng location;
}

class PlaceCandidate {
  const PlaceCandidate({
    required this.name,
    required this.category,
    required this.location,
  });

  final String name;
  final String category;
  final LatLng location;
}

class RankedPlace {
  const RankedPlace({
    required this.place,
    required this.score,
    required this.explanation,
  });

  final PlaceCandidate place;

  /// Lower is better.
  final double score;
  final String explanation;
}

/// Strategy: interchangeable ways to rank candidate places.
abstract class RecommendationStrategy {
  const RecommendationStrategy();

  String get label;
  String get description;

  List<RankedPlace> rank(
    List<PlaceCandidate> candidates,
    List<Participant> participants,
  );
}

/// Ranks by straight-line distance to a single reference point.
class ClosestToPointStrategy extends RecommendationStrategy {
  const ClosestToPointStrategy({required this.reference});

  final LatLng reference;

  @override
  String get label => 'Más cerca';

  @override
  String get description => 'Lugares más cercanos al punto elegido en el mapa.';

  @override
  List<RankedPlace> rank(
    List<PlaceCandidate> candidates,
    List<Participant> participants,
  ) {
    final ranked = [
      for (final place in candidates)
        _closest(place, _distanceMeters(reference, place.location)),
    ];
    return _sorted(ranked);
  }

  RankedPlace _closest(PlaceCandidate place, double meters) => RankedPlace(
        place: place,
        score: meters,
        explanation: '${formatDistance(meters)} del punto elegido',
      );
}

/// Prefers places where no participant travels much more than the others:
/// score = largest distance + spread (standard deviation) of the distances.
class FairTravelStrategy extends RecommendationStrategy {
  const FairTravelStrategy();

  @override
  String get label => 'Más justo';

  @override
  String get description =>
      'Equilibra el viaje: evita que alguien recorra mucho más que los demás.';

  @override
  List<RankedPlace> rank(
    List<PlaceCandidate> candidates,
    List<Participant> participants,
  ) {
    if (participants.isEmpty) return const [];

    final ranked = <RankedPlace>[];
    for (final place in candidates) {
      final distances = [
        for (final participant in participants)
          _distanceMeters(participant.location, place.location),
      ];
      final longest = distances.reduce(math.max);
      final shortest = distances.reduce(math.min);
      ranked.add(RankedPlace(
        place: place,
        score: longest + _standardDeviation(distances),
        explanation:
            'Máx. ${formatDistance(longest)} · diferencia ${formatDistance(longest - shortest)}',
      ));
    }
    return _sorted(ranked);
  }

  /// Calculates rankings in a background Dart Isolate to prevent UI frame drops.
  Future<List<RankedPlace>> rankAsync(
    List<PlaceCandidate> candidates,
    List<Participant> participants,
  ) async {
    if (participants.isEmpty) return const [];
    final rawCandidates = candidates.asMap().entries.map((e) => {
      'index': e.key,
      'name': e.value.name,
      'category': e.value.category,
      'lat': e.value.location.latitude,
      'lng': e.value.location.longitude,
    }).toList();

    final rawParticipants = participants.map((p) => {
      'name': p.name,
      'lat': p.location.latitude,
      'lng': p.location.longitude,
    }).toList();

    final isolateResults = await GeoIsolate.rankPlacesFairTravel(
      rawCandidates: rawCandidates,
      rawParticipants: rawParticipants,
    );

    return isolateResults.map((res) {
      final candMap = res['candidate'] as Map<String, dynamic>;
      final index = candMap['index'] as int;
      final maxDist = (res['maxDistance'] as num).toDouble();
      final minDist = (res['minDistance'] as num).toDouble();
      return RankedPlace(
        place: candidates[index],
        score: (res['score'] as num).toDouble(),
        explanation: 'Máx. ${formatDistance(maxDist)} · diferencia ${formatDistance(maxDist - minDist)}',
      );
    }).toList();
  }
}

/// Category of places that are exposed to the weather.
const outdoorCategory = 'Parque';

/// Decorator: wraps any strategy and pushes outdoor places down the ranking.
/// Meant to be used only when rain is likely; the penalty grows with the
/// probability (up to 5 km equivalent).
class RainAwareStrategy extends RecommendationStrategy {
  const RainAwareStrategy({required this.inner, required this.rainProbability});

  final RecommendationStrategy inner;

  /// Probability of rain, 0 to 100.
  final int rainProbability;

  @override
  String get label => inner.label;

  @override
  String get description => inner.description;

  @override
  List<RankedPlace> rank(
    List<PlaceCandidate> candidates,
    List<Participant> participants,
  ) {
    final penalty = 5000.0 * rainProbability / 100;
    final adjusted = [
      for (final ranked in inner.rank(candidates, participants))
        ranked.place.category == outdoorCategory
            ? RankedPlace(
                place: ranked.place,
                score: ranked.score + penalty,
                explanation: '${ranked.explanation} · al aire libre, lluvia probable',
              )
            : ranked,
    ];
    return _sorted(adjusted);
  }
}

String formatDistance(double meters) {
  if (meters < 1000) return '${meters.round()} m';
  return '${(meters / 1000).toStringAsFixed(2)} km';
}

double _distanceMeters(LatLng a, LatLng b) =>
    const Distance().as(LengthUnit.Meter, a, b);

double _standardDeviation(List<double> values) {
  final mean = values.reduce((a, b) => a + b) / values.length;
  final variance =
      values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
          values.length;
  return math.sqrt(variance);
}

List<RankedPlace> _sorted(List<RankedPlace> ranked) => ranked
  ..sort((a, b) {
    final byScore = a.score.compareTo(b.score);
    return byScore != 0 ? byScore : a.place.name.compareTo(b.place.name);
  });
