import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:espoti/core/services/routing_service.dart';

void main() {
  group('RoutingService - Algoritmo de Sugerencia', () {
    test('sugiere ir a pie cuando la distancia es menor a 1.5 km', () {
      expect(
        RoutingService.calculateSuggestion(0.5),
        'Sugerencia: Ir a pie (aprox. 15 min)',
      );
      expect(
        RoutingService.calculateSuggestion(1.49),
        'Sugerencia: Ir a pie (aprox. 15 min)',
      );
      expect(
        RoutingService.getSuggestionIcon(1.0),
        Icons.directions_walk,
      );
    });

    test('sugiere transporte público o bicicleta entre 1.5 km y 8 km', () {
      expect(
        RoutingService.calculateSuggestion(1.5),
        'Sugerencia: Transporte Público / Bicicleta (aprox. 25 min)',
      );
      expect(
        RoutingService.calculateSuggestion(4.2),
        'Sugerencia: Transporte Público / Bicicleta (aprox. 25 min)',
      );
      expect(
        RoutingService.calculateSuggestion(8.0),
        'Sugerencia: Transporte Público / Bicicleta (aprox. 25 min)',
      );
      expect(
        RoutingService.getSuggestionIcon(5.0),
        Icons.directions_bike,
      );
    });

    test('sugiere vehículo o taxi cuando la distancia es mayor a 8 km', () {
      expect(
        RoutingService.calculateSuggestion(8.1),
        'Sugerencia: Vehículo / Taxi (aprox. 35 min)',
      );
      expect(
        RoutingService.calculateSuggestion(20.0),
        'Sugerencia: Vehículo / Taxi (aprox. 35 min)',
      );
      expect(
        RoutingService.getSuggestionIcon(12.0),
        Icons.directions_car,
      );
    });
  });

  group('RoutingService - Consulta de Ruta OSRM', () {
    test('procesa respuesta de OSRM correctamente y genera los puntos de la polilínea', () async {
      final mockClient = MockClient((request) async {
        final mockResponse = {
          'code': 'Ok',
          'routes': [
            {
              'distance': 2500.0,
              'geometry': {
                'coordinates': [
                  [-74.0817, 4.6097],
                  [-74.0750, 4.6150],
                  [-74.0650, 4.6300],
                ],
              },
            }
          ],
        };
        return http.Response(jsonEncode(mockResponse), 200);
      });

      final result = await RoutingService().getRoute(
        origin: const LatLng(4.6097, -74.0817),
        destination: const LatLng(4.6300, -74.0650),
        client: mockClient,
      );

      expect(result.points.length, 3);
      expect(result.points.first.latitude, 4.6097);
      expect(result.points.first.longitude, -74.0817);
      expect(result.distanceKm, 2.5);
      expect(
        result.suggestion,
        'Sugerencia: Transporte Público / Bicicleta (aprox. 25 min)',
      );
    });

    test('genera ruta de respaldo si el servicio OSRM responde con error', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Service Unavailable', 503);
      });

      const origin = LatLng(4.6097, -74.0817);
      const destination = LatLng(4.6300, -74.0650);

      final result = await RoutingService().getRoute(
        origin: origin,
        destination: destination,
        client: mockClient,
      );

      expect(result.points.length, 2);
      expect(result.points[0], origin);
      expect(result.points[1], destination);
      expect(result.distanceKm, greaterThan(0));
    });
  });
}
