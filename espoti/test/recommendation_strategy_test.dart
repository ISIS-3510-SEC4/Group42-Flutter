import 'package:espoti/features/meetings/recommendation/recommendation_strategy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  // Along one meridian: 0.01 degrees of latitude is about 1.11 km.
  const west = Participant(name: 'A', location: LatLng(0, 0));
  const east = Participant(name: 'B', location: LatLng(0.10, 0));

  PlaceCandidate place(String name, double lat) => PlaceCandidate(
        name: name,
        category: 'Cafetería',
        location: LatLng(lat, 0),
      );

  final nearA = place('Near A', 0.01);
  final middle = place('Middle', 0.05);

  test('closest strategy ranks by distance to the reference point', () {
    const strategy = ClosestToPointStrategy(reference: LatLng(0, 0));

    final ranked = strategy.rank([middle, nearA], [west, east]);

    expect(ranked.map((r) => r.place.name), ['Near A', 'Middle']);
  });

  test('fair strategy prefers the place that balances both travelers', () {
    const strategy = FairTravelStrategy();

    final ranked = strategy.rank([nearA, middle], [west, east]);

    expect(ranked.first.place.name, 'Middle');
    expect(ranked.first.explanation, contains('diferencia 0 m'));
  });

  test('same places are ordered differently by each strategy', () {
    const closest = ClosestToPointStrategy(reference: LatLng(0, 0));
    const fair = FairTravelStrategy();
    final candidates = [nearA, middle];

    final closestFirst = closest.rank(candidates, [west, east]).first;
    final fairFirst = fair.rank(candidates, [west, east]).first;

    expect(closestFirst.place.name, isNot(fairFirst.place.name));
  });

  test('fair strategy returns nothing without participants', () {
    expect(const FairTravelStrategy().rank([nearA], const []), isEmpty);
  });

  test('formats short and long distances', () {
    expect(formatDistance(40.4), '40 m');
    expect(formatDistance(2500), '2.50 km');
  });
}
