import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class PlaceSuggestion {
  final String title;
  final String subtitle;
  final LatLng point;

  const PlaceSuggestion({
    required this.title,
    required this.subtitle,
    required this.point,
  });

  @override
  String toString() => '$title ($subtitle)';
}

class PlaceSearchService {
  static final PlaceSearchService _instance = PlaceSearchService._internal();
  factory PlaceSearchService() => _instance;
  PlaceSearchService._internal();

  // Busca lugares y direcciones mediante Photon (OpenStreetMap) con respaldo en Nominatim
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
      // 1. Consulta al servicio Photon con sesgo por coordenadas GPS del usuario
      final buffer = StringBuffer('https://photon.komoot.io/api/?q=${Uri.encodeComponent(cleanQuery)}&limit=5');
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

              results.add(
                PlaceSuggestion(
                  title: title,
                  subtitle: subtitleParts.join(', '),
                  point: LatLng(lat, lon),
                ),
              );
            }
          }
          if (results.isNotEmpty) {
            return results;
          }
        }
      }

      // 2. Respaldo secundario mediante Nominatim
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
          return list.map<PlaceSuggestion>((item) {
            final lat = double.tryParse(item['lat'].toString()) ?? 0.0;
            final lon = double.tryParse(item['lon'].toString()) ?? 0.0;
            final name = item['name'] as String? ?? '';
            final displayName = item['display_name'] as String? ?? '';

            return PlaceSuggestion(
              title: name.isNotEmpty ? name : displayName.split(',').first,
              subtitle: displayName,
              point: LatLng(lat, lon),
            );
          }).where((s) => s.point.latitude != 0.0 && s.point.longitude != 0.0).toList();
        }
      }
    } catch (e) {
      debugPrint('Error buscando lugares: $e');
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }

    return [];
  }
}
