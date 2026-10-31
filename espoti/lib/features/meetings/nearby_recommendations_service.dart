import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../core/cache/lru_cache.dart';
import '../../models/meeting.dart';
import 'recommendation/recommendation_strategy.dart';
import 'zone_places_store.dart';

class NearbyRecommendationsService {
  NearbyRecommendationsService({
    http.Client? client,
    LruCache<String, List<PlaceCandidate>>? cache,
    ZonePlacesStore? store,
  })  : _client = client ?? http.Client(),
        _cache = cache ?? _sharedCache,
        _store = store ?? ZonePlacesStore();

  /// Shared by every screen: the vote page creates a new service each time.
  /// Overpass is slow and rate limited, and places in a zone rarely change.
  static final _sharedCache = LruCache<String, List<PlaceCandidate>>(20);

  final http.Client _client;
  final LruCache<String, List<PlaceCandidate>> _cache;
  final ZonePlacesStore _store;

  // Rounded to ~110 m so taps on the same block reuse the same result.
  static String _zoneKey(LatLng location, int radiusMeters) =>
      '${location.latitude.toStringAsFixed(3)},'
      '${location.longitude.toStringAsFixed(3)},$radiusMeters';

  /// Named places around [location], with coordinates and without ranking.
  Future<List<PlaceCandidate>> findCandidates(
    LatLng location, {
    int radiusMeters = 1500,
  }) async {
    final key = _zoneKey(location, radiusMeters);
    final cached = _cache.get(key);
    if (cached != null) return cached;

    final query = '''
[out:json][timeout:25];
(
  node(around:$radiusMeters,${location.latitude},${location.longitude})["amenity"~"restaurant|cafe|fast_food|bar|pub"]["name"];
  way(around:$radiusMeters,${location.latitude},${location.longitude})["amenity"~"restaurant|cafe|fast_food|bar|pub"]["name"];
  relation(around:$radiusMeters,${location.latitude},${location.longitude})["amenity"~"restaurant|cafe|fast_food|bar|pub"]["name"];
  node(around:$radiusMeters,${location.latitude},${location.longitude})["leisure"="park"]["name"];
  way(around:$radiusMeters,${location.latitude},${location.longitude})["leisure"="park"]["name"];
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
        category: tags['leisure'] == 'park'
            ? outdoorCategory
            : switch (tags['amenity']) {
                'cafe' => 'Cafetería',
                'restaurant' => 'Restaurante',
                'fast_food' => 'Comida rápida',
                'bar' || 'pub' => 'Bar',
                _ => 'Lugar cercano',
              },
        location: LatLng(latitude.toDouble(), longitude.toDouble()),
      ));
    }
    _cache.put(key, candidates);
    // Saved on disk in the background: the user does not wait for it.
    _store.save(key, candidates).catchError((Object error) {
      debugPrint('Places not stored on disk: $error');
    });
    return candidates;
  }

  /// Places last found on disk for this zone, used when Overpass fails.
  Future<StoredPlaces?> storedCandidates(
    LatLng location, {
    int radiusMeters = 1500,
  }) =>
      _store.read(_zoneKey(location, radiusMeters));

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
