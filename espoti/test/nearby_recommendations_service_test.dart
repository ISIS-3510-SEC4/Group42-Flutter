import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:espoti/features/meetings/nearby_recommendations_service.dart';

void main() {
  test('calculates and displays each place distance from its own coordinates',
      () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'elements': [
            {
              'type': 'node',
              'lat': 0,
              'lon': 0,
              'tags': {'name': 'At the selected point', 'amenity': 'cafe'},
            },
            {
              'type': 'node',
              'lat': 0.00036,
              'lon': 0,
              'tags': {'name': 'Forty meters away', 'amenity': 'cafe'},
            },
            {
              'type': 'way',
              'center': {'lat': 0.0009, 'lon': 0},
              'tags': {
                'name': 'One hundred meters away',
                'amenity': 'restaurant'
              },
            },
          ],
        }),
        200,
      );
    });
    final service = NearbyRecommendationsService(client: client);
    addTearDown(service.close);

    final places = await service.findNearbyPlaces(const LatLng(0, 0));

    expect(places.map((place) => place.placeName), [
      'At the selected point',
      'Forty meters away',
      'One hundred meters away',
    ]);
    expect(places.map((place) => place.distanceLabel), [
      '0 m del punto elegido',
      '40 m del punto elegido',
      '100 m del punto elegido',
    ]);
  });
}
