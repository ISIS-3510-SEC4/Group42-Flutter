import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../concurrency/geo_isolate.dart';

class RouteRecommendation {
  final List<LatLng> points;
  final double distanceKm;
  final String suggestion;
  final IconData icon;

  const RouteRecommendation({
    required this.points,
    required this.distanceKm,
    required this.suggestion,
    required this.icon,
  });
}

class RoutingService {
  static final RoutingService _instance = RoutingService._internal();
  factory RoutingService() => _instance;
  RoutingService._internal();

  // Algoritmo de sugerencia según distancia en kilómetros
  static String calculateSuggestion(double distanceKm) {
    if (distanceKm < 1.5) {
      return 'Sugerencia: Ir a pie (aprox. 15 min)';
    } else if (distanceKm <= 8.0) {
      return 'Sugerencia: Transporte Público / Bicicleta (aprox. 25 min)';
    } else {
      return 'Sugerencia: Vehículo / Taxi (aprox. 35 min)';
    }
  }

  // Icono representativo según el medio de transporte sugerido
  static IconData getSuggestionIcon(double distanceKm) {
    if (distanceKm < 1.5) {
      return Icons.directions_walk;
    } else if (distanceKm <= 8.0) {
      return Icons.directions_bike;
    } else {
      return Icons.directions_car;
    }
  }

  // Consulta el servicio OSRM para obtener la polilínea de la ruta real
  Future<RouteRecommendation> getRoute({
    required LatLng origin,
    required LatLng destination,
    http.Client? client,
  }) async {
    final httpClient = client ?? http.Client();
    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}?overview=full&geometries=geojson',
      );

      final response = await httpClient.get(url);

      if (response.statusCode == 200) {
        // Offload route parsing and coordinate mapping to background Isolate
        final parsed = await GeoIsolate.parseOsrmRoute(response.body);
        if (parsed != null) {
          final rawPoints = parsed['points'] as List;
          final points = rawPoints
              .map<LatLng>((p) => LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()))
              .toList();
          final distanceKm = (parsed['distanceMeters'] as num).toDouble() / 1000.0;

          return RouteRecommendation(
            points: points,
            distanceKm: distanceKm,
            suggestion: calculateSuggestion(distanceKm),
            icon: getSuggestionIcon(distanceKm),
          );
        }
      }
    } catch (e) {
      debugPrint('Error al consultar ruta OSRM: $e');
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }

    // Respaldo en caso de error de red: cálculo en línea recta geodésica
    final distanceMeters = Geolocator.distanceBetween(
      origin.latitude,
      origin.longitude,
      destination.latitude,
      destination.longitude,
    );
    final distanceKm = distanceMeters / 1000.0;

    return RouteRecommendation(
      points: [origin, destination],
      distanceKm: distanceKm,
      suggestion: calculateSuggestion(distanceKm),
      icon: getSuggestionIcon(distanceKm),
    );
  }
}
