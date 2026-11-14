import 'package:espoti/features/meetings/recommendation/recommendation_strategy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

// La estrategia "más justa" (FairTravelStrategy) se eliminó del proyecto;
// estas pruebas cubren la estrategia que queda (más cercana) y el decorador
// de lluvia.
void main() {
  // Along one meridian: 0.01 degrees of latitude is about 1.11 km.
  PlaceCandidate place(String name, double lat) => PlaceCandidate(
        name: name,
        category: 'Cafe',
        location: LatLng(lat, 0),
      );

  final nearA = place('Near A', 0.01);
  final middle = place('Middle', 0.05);

  test('closest strategy ranks by distance to the reference point', () {
    const strategy = ClosestToPointStrategy(reference: LatLng(0, 0));

    final ranked = strategy.rank([middle, nearA], const []);

    expect(ranked.map((r) => r.place.name), ['Near A', 'Middle']);
    expect(ranked.first.explanation, contains('from the chosen point'));
  });

  test('rain pushes outdoor places down without discarding them', () {
    const park = PlaceCandidate(
      name: 'Park',
      category: outdoorCategory,
      location: LatLng(0.005, 0),
    );
    const closest = ClosestToPointStrategy(reference: LatLng(0, 0));

    final dry = closest.rank([park, nearA, middle], const []);
    final rainy = const RainAwareStrategy(inner: closest, rainProbability: 80)
        .rank([park, nearA, middle], const []);

    // Dry: the park is the closest. Rainy: it drops behind the indoor place
    // that was farther, but still beats the one that is much farther.
    expect(dry.first.place.name, 'Park');
    expect(rainy.map((r) => r.place.name), ['Near A', 'Park', 'Middle']);
    expect(rainy[1].explanation, contains('rain likely'));
    expect(rainy.first.explanation, isNot(contains('rain')));
  });

  test('rain decorator keeps the label of the wrapped strategy', () {
    const closest = ClosestToPointStrategy(reference: LatLng(0, 0));
    const strategy = RainAwareStrategy(inner: closest, rainProbability: 60);

    expect(strategy.label, closest.label);
  });

  test('formats short and long distances', () {
    expect(formatDistance(40.4), '40 m');
    expect(formatDistance(2500), '2.50 km');
  });
}
