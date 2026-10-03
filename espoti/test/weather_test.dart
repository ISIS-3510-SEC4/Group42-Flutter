import 'dart:convert';

import 'package:espoti/features/meetings/recommendation/meeting_schedule.dart';
import 'package:espoti/features/meetings/recommendation/weather_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('parseMeetingDateTime', () {
    // Saturday 2026-10-03 10:00.
    final now = DateTime(2026, 10, 3, 10);

    test('reads weekday names and am/pm times', () {
      expect(parseMeetingDateTime('Sunday', '2:00 pm', now: now),
          DateTime(2026, 10, 4, 14));
    });

    test('same weekday with the hour passed means next week', () {
      expect(parseMeetingDateTime('Saturday', '9:00 am', now: now),
          DateTime(2026, 10, 10, 9));
    });

    test('reads Spanish days, 24 hour times and tomorrow', () {
      expect(parseMeetingDateTime('lunes', '14:30', now: now),
          DateTime(2026, 10, 5, 14, 30));
      expect(parseMeetingDateTime('mañana', '12 am', now: now),
          DateTime(2026, 10, 4, 0));
    });

    test('returns null when it cannot understand the text', () {
      expect(parseMeetingDateTime('someday', '2 pm', now: now), isNull);
      expect(parseMeetingDateTime('Sunday', 'afternoon', now: now), isNull);
    });
  });

  group('WeatherService', () {
    http.Response forecast() => http.Response(
          jsonEncode({
            'hourly': {
              'time': ['2026-10-04T13:00', '2026-10-04T14:00'],
              'precipitation_probability': [20, 70],
            },
          }),
          200,
        );

    test('returns the rain probability for the meeting hour', () async {
      final service = WeatherService(client: MockClient((_) async => forecast()));

      final result = await service.forecastAt(
          const LatLng(4.6, -74.07), DateTime(2026, 10, 4, 14));

      expect(result.rainProbability, 70);
      expect(result.rainLikely, isTrue);
    });

    test('fails when the hour is outside the forecast', () async {
      final service = WeatherService(client: MockClient((_) async => forecast()));

      expect(
        service.forecastAt(const LatLng(4.6, -74.07), DateTime(2026, 11, 1, 9)),
        throwsA(isA<StateError>()),
      );
    });

    test('fails when the service responds with an error', () async {
      final service =
          WeatherService(client: MockClient((_) async => http.Response('', 500)));

      expect(
        service.forecastAt(const LatLng(4.6, -74.07), DateTime(2026, 10, 4, 14)),
        throwsException,
      );
    });
  });
}
