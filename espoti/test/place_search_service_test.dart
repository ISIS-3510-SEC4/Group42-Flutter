import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:espoti/core/services/place_search_service.dart';

void main() {
  group('PlaceSearchService - Autocompletado y Búsqueda de Lugares', () {
    test('retorna lista vacía si la consulta tiene menos de 2 caracteres', () async {
      final results = await PlaceSearchService().searchPlaces('a');
      expect(results, isEmpty);
    });

    test('procesa respuesta de Photon correctamente con título, subtítulo y coordenadas', () async {
      final mockClient = MockClient((request) async {
        final mockResponse = {
          'type': 'FeatureCollection',
          'features': [
            {
              'type': 'Feature',
              'properties': {
                'name': 'Centro Comercial Andino',
                'street': 'Carrera 12',
                'housenumber': '82-71',
                'district': 'Chicó Lago',
                'city': 'Bogotá',
              },
              'geometry': {
                'type': 'Point',
                'coordinates': [-74.0531, 4.6669],
              },
            }
          ],
        };
        return http.Response(jsonEncode(mockResponse), 200);
      });

      final results = await PlaceSearchService().searchPlaces(
        'centro comercial',
        userLocation: const LatLng(4.6097, -74.0817),
        client: mockClient,
      );

      expect(results.length, 1);
      expect(results.first.title, 'Centro Comercial Andino');
      expect(results.first.subtitle, contains('Carrera 12 #82-71'));
      expect(results.first.point.latitude, 4.6669);
      expect(results.first.point.longitude, -74.0531);
    });

    test('utiliza respaldo de Nominatim cuando Photon no arroja resultados', () async {
      final mockClient = MockClient((request) async {
        if (request.url.host.contains('photon')) {
          return http.Response(jsonEncode({'type': 'FeatureCollection', 'features': []}), 200);
        } else {
          final nomResponse = [
            {
              'name': 'Calle 72',
              'display_name': 'Calle 72, Chapinero, Bogotá, Colombia',
              'lat': '4.6550',
              'lon': '-74.0600',
            }
          ];
          return http.Response(jsonEncode(nomResponse), 200);
        }
      });

      final results = await PlaceSearchService().searchPlaces(
        'Calle 72',
        client: mockClient,
      );

      expect(results.length, 1);
      expect(results.first.title, 'Calle 72');
      expect(results.first.point.latitude, 4.6550);
      expect(results.first.point.longitude, -74.0600);
    });

    test('maneja excepciones de red retornando lista vacía', () async {
      final mockClient = MockClient((request) async {
        throw Exception('Fallo de conexión');
      });

      final results = await PlaceSearchService().searchPlaces(
        'Prueba',
        client: mockClient,
      );

      expect(results, isEmpty);
    });
  });
}
