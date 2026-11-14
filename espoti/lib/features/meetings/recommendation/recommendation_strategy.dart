import 'package:latlong2/latlong.dart';

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
/// (La estrategia "más justa" se eliminó; queda la más cercana y el decorador
/// de lluvia. Se mantiene la interfaz por si se agregan otras.)
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
  String get label => 'Closest';

  @override
  String get description => 'Places closest to the point chosen on the map.';

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
        explanation: '${formatDistance(meters)} from the chosen point',
      );
}

/// Category of places that are exposed to the weather.
const outdoorCategory = 'Park';

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
                explanation: '${ranked.explanation} · outdoors, rain likely',
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

List<RankedPlace> _sorted(List<RankedPlace> ranked) => ranked
  ..sort((a, b) {
    final byScore = a.score.compareTo(b.score);
    return byScore != 0 ? byScore : a.place.name.compareTo(b.place.name);
  });
