import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../models/meeting.dart';

class NearbyRecommendationsService {
  NearbyRecommendationsService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<Meeting>> findNearbyPlaces(
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

    const distance = Distance();
    final places = <({Meeting meeting, double distanceKm})>[];
    for (final element in decoded['elements'] as List) {
      if (element is! Map<String, dynamic>) continue;
      final tags = element['tags'];
      if (tags is! Map<String, dynamic>) continue;

      final latitude = element['lat'] ?? (element['center'] as Map?)?['lat'];
      final longitude = element['lon'] ?? (element['center'] as Map?)?['lon'];
      final name = tags['name'];
      if (latitude is! num || longitude is! num || name is! String) continue;

      final placePoint = LatLng(latitude.toDouble(), longitude.toDouble());
      final distanceMeters =
          distance.as(LengthUnit.Meter, location, placePoint);
      final distanceKm = distanceMeters / 1000.0;
      final category = switch (tags['amenity']) {
        'cafe' => 'Cafetería',
        'restaurant' => 'Restaurante',
        'fast_food' => 'Comida rápida',
        'bar' || 'pub' => 'Bar',
        _ => 'Lugar cercano',
      };
      places.add((
        meeting: Meeting(
          placeName: name,
          timeLabel: category,
          distanceLabel: '${_formatDistance(distanceMeters)} del punto elegido',
          rating: null,
          imageUrl: '',
        ),
        distanceKm: distanceKm,
      ));
    }

    places
        .sort((first, second) => first.distanceKm.compareTo(second.distanceKm));
    return places.take(10).map((place) => place.meeting).toList();
  }

  void close() => _client.close();
}

String _formatDistance(double distanceMeters) {
  if (distanceMeters < 1000) {
    return '${distanceMeters.round()} m';
  }
  return '${(distanceMeters / 1000).toStringAsFixed(2)} km';
}
