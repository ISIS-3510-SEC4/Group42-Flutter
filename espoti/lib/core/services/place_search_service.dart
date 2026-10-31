import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../offline/local_store.dart';

class PlaceSuggestion {
  final String title;
  final String subtitle;
  final LatLng point;

  const PlaceSuggestion({
    required this.title,
    required this.subtitle,
    required this.point,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'subtitle': subtitle,
        'lat': point.latitude,
        'lng': point.longitude,
      };

  factory PlaceSuggestion.fromJson(Map<String, dynamic> json) => PlaceSuggestion(
        title: json['title'] as String? ?? '',
        subtitle: json['subtitle'] as String? ?? '',
        point: LatLng(
          (json['lat'] as num?)?.toDouble() ?? 0.0,
          (json['lng'] as num?)?.toDouble() ?? 0.0,
        ),
      );

  @override
  String toString() => '$title ($subtitle)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaceSuggestion &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          subtitle == other.subtitle &&
          point.latitude == other.point.latitude &&
          point.longitude == other.point.longitude;

  @override
  int get hashCode => Object.hash(title, subtitle, point.latitude, point.longitude);
}

class PlaceSearchService {
  static final PlaceSearchService _instance = PlaceSearchService._internal();
  factory PlaceSearchService() => _instance;
  PlaceSearchService._internal();

  /// Retrieves recently searched or saved places from persistent local storage.
  Future<List<PlaceSuggestion>> getRecentSearches({int limit = 10}) async {
    return LocalStore.instance.getRecentPlaces(limit: limit);
  }

  /// Manually records a place selection into persistent storage.
  Future<void> recordPlaceSelection(PlaceSuggestion place, {String? query}) async {
    await LocalStore.instance.saveRecentPlace(place, query: query);
  }

  /// Searches places via Photon (OpenStreetMap) with Nominatim fallback and
  /// offline local storage fallback.
  Future<List<PlaceSuggestion>> searchPlaces(
    String query, {
    LatLng? userLocation,
    http.Client? client,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.length < 2) {
      return [];
    }

    final httpClient = client ?? http.Client();

    try {
      // 1. Query Photon service with user location bias
      final buffer = StringBuffer(
          'https://photon.komoot.io/api/?q=${Uri.encodeComponent(cleanQuery)}&limit=5');
      if (userLocation != null) {
        buffer.write('&lat=${userLocation.latitude}&lon=${userLocation.longitude}');
      }

      final photonUri = Uri.parse(buffer.toString());
      final response = await httpClient.get(
        photonUri,
        headers: {'User-Agent': 'EspotiApp/1.0'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final features = data['features'] as List?;
        if (features != null && features.isNotEmpty) {
          final results = <PlaceSuggestion>[];
          for (final feature in features) {
            final properties = feature['properties'] as Map<String, dynamic>? ?? {};
            final geometry = feature['geometry'] as Map<String, dynamic>? ?? {};
            final coordinates = geometry['coordinates'] as List?;

            if (coordinates != null && coordinates.length >= 2) {
              final lon = (coordinates[0] as num).toDouble();
              final lat = (coordinates[1] as num).toDouble();

              final name = properties['name'] as String?;
              final street = properties['street'] as String?;
              final housenumber = properties['housenumber'] as String?;
              final district = properties['district'] as String?;
              final city = properties['city'] as String? ?? properties['state'] as String?;

              String title;
              if (name != null && name.isNotEmpty) {
                title = name;
              } else if (street != null && street.isNotEmpty) {
                title = housenumber != null ? '$street #$housenumber' : street;
              } else {
                title = cleanQuery;
              }

              final subtitleParts = <String>[];
              if (street != null && street != title) {
                subtitleParts.add(housenumber != null ? '$street #$housenumber' : street);
              }
              if (district != null && district.isNotEmpty) {
                subtitleParts.add(district);
              }
              if (city != null && city.isNotEmpty) {
                subtitleParts.add(city);
              }

              final suggestion = PlaceSuggestion(
                title: title,
                subtitle: subtitleParts.join(', '),
                point: LatLng(lat, lon),
              );
              results.add(suggestion);

              // Cache place into persistent SQLite storage
              unawaited(LocalStore.instance.saveRecentPlace(
                suggestion,
                query: cleanQuery,
                category: properties['osm_value'] as String?,
              ));
            }
          }
          if (results.isNotEmpty) {
            return results;
          }
        }
      }

      // 2. Secondary fallback via Nominatim
      final nominatimUri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(cleanQuery)}&format=json&limit=5&addressdetails=1',
      );
      final nomResponse = await httpClient.get(
        nominatimUri,
        headers: {'User-Agent': 'EspotiApp/1.0'},
      );

      if (nomResponse.statusCode == 200) {
        final list = jsonDecode(nomResponse.body) as List?;
        if (list != null) {
          final results = list.map<PlaceSuggestion>((item) {
            final lat = double.tryParse(item['lat'].toString()) ?? 0.0;
            final lon = double.tryParse(item['lon'].toString()) ?? 0.0;
            final name = item['name'] as String? ?? '';
            final displayName = item['display_name'] as String? ?? '';

            final suggestion = PlaceSuggestion(
              title: name.isNotEmpty ? name : displayName.split(',').first,
              subtitle: displayName,
              point: LatLng(lat, lon),
            );

            // Cache place into persistent storage
            unawaited(LocalStore.instance.saveRecentPlace(
              suggestion,
              query: cleanQuery,
            ));

            return suggestion;
          }).where((s) => s.point.latitude != 0.0 && s.point.longitude != 0.0).toList();

          if (results.isNotEmpty) return results;
        }
      }
    } catch (e) {
      debugPrint('PlaceSearchService: Network error ($e). Checking offline cache...');
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }

    // 3. Offline persistent fallback: Search cached places from SQLite
    try {
      final cached = await LocalStore.instance.searchCachedPlaces(cleanQuery);
      if (cached.isNotEmpty) {
        return cached;
      }
    } catch (e) {
      debugPrint('PlaceSearchService: Cache lookup error: $e');
    }

    return [];
  }
}
