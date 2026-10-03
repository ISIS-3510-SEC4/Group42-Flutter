import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../models/meeting.dart';
import 'recommendation/recommendation_strategy.dart';

class NearbyRecommendationsService {
  NearbyRecommendationsService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  /// Named places around [location], with coordinates and without ranking.
  Future<List<PlaceCandidate>> findCandidates(
    LatLng location, {
    int radiusMeters = 1500,
  }) async {
    final query = '''
[out:json][timeout:25];
(
  node(around:$radiusMeters,${location.latitude},${location.longitude})["amenity"~"restaurant|cafe|fast_food|bar|pub"]["name"];
  way(around:$radiusMeters,${location.latitude},${location.longitude})["amenity"~"restaurant|cafe|fast_food|bar|pub"]["name"];
  relation(around:$radiusMeters,${location.latitude},${location.longitude})["amenity"~"restaurant|cafe|fast_food|bar|pub"]["name"];
);
out center tags;
''';
    final response = await _client.post(
      Uri.https('overpass-api.de', '/api/interpreter'),
      headers: const {
        'Content-Type': 'application/x-www-form-urlencoded',
        'User-Agent': 'Espoti/0.1.0 (Flutter app)',
      },
      body: {'data': query},
    );

    if (response.statusCode != 200) {
      throw Exception('No fue posible consultar lugares cercanos.');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> || decoded['elements'] is! List) {
      throw const FormatException(
          'Respuesta inválida del servicio de lugares.');
    }

    final candidates = <PlaceCandidate>[];
    for (final element in decoded['elements'] as List) {
      if (element is! Map<String, dynamic>) continue;
      final tags = element['tags'];
      if (tags is! Map<String, dynamic>) continue;

      final latitude = element['lat'] ?? (element['center'] as Map?)?['lat'];
      final longitude = element['lon'] ?? (element['center'] as Map?)?['lon'];
      final name = tags['name'];
      if (latitude is! num || longitude is! num || name is! String) continue;

      candidates.add(PlaceCandidate(
        name: name,
        category: switch (tags['amenity']) {
          'cafe' => 'Cafetería',
          'restaurant' => 'Restaurante',
          'fast_food' => 'Comida rápida',
          'bar' || 'pub' => 'Bar',
          _ => 'Lugar cercano',
        },
        location: LatLng(latitude.toDouble(), longitude.toDouble()),
      ));
    }
    return candidates;
  }

  Future<List<Meeting>> findNearbyPlaces(
    LatLng location, {
    int radiusMeters = 1500,
  }) async {
    final candidates =
        await findCandidates(location, radiusMeters: radiusMeters);
    final ranked =
        ClosestToPointStrategy(reference: location).rank(candidates, const []);

    return ranked
        .take(10)
        .map((place) => Meeting(
              placeName: place.place.name,
              timeLabel: place.place.category,
              distanceLabel: place.explanation,
              rating: null,
              imageUrl: '',
            ))
        .toList();
  }

  void close() => _client.close();
}
