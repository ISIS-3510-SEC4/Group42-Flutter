import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Rain at or above this probability (%) counts as "rain likely".
const rainThreshold = 50;

class WeatherForecast {
  const WeatherForecast({required this.time, required this.rainProbability});

  final DateTime time;

  /// Probability of precipitation, 0 to 100.
  final int rainProbability;

  bool get rainLikely => rainProbability >= rainThreshold;
}

/// Hourly rain forecast from Open-Meteo (free, no API key).
class WeatherService {
  WeatherService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Forecast for the hour closest to [when], at [location].
  /// Throws if the service fails or [when] is outside the forecast window.
  Future<WeatherForecast> forecastAt(LatLng location, DateTime when) async {
    final response = await _client.get(Uri.https(
      'api.open-meteo.com',
      '/v1/forecast',
      {
        'latitude': location.latitude.toString(),
        'longitude': location.longitude.toString(),
        'hourly': 'precipitation_probability',
        'timezone': 'auto',
        'forecast_days': '10',
      },
    ));

    if (response.statusCode != 200) {
      throw Exception('No fue posible consultar el clima.');
    }

    final decoded = jsonDecode(response.body);
    final hourly = decoded is Map<String, dynamic> ? decoded['hourly'] : null;
    final times = hourly is Map ? hourly['time'] : null;
    final probabilities =
        hourly is Map ? hourly['precipitation_probability'] : null;
    if (times is! List || probabilities is! List) {
      throw const FormatException('Respuesta inválida del servicio de clima.');
    }

    // The API answers in the place's local time, same clock as the form.
    final target = DateTime(when.year, when.month, when.day, when.hour)
        .add(Duration(hours: when.minute >= 30 ? 1 : 0));
    for (var i = 0; i < times.length && i < probabilities.length; i++) {
      final hour = DateTime.tryParse('${times[i]}');
      final probability = probabilities[i];
      if (hour != null && hour == target && probability is num) {
        return WeatherForecast(time: hour, rainProbability: probability.round());
      }
    }
    throw StateError('Hora fuera del pronóstico disponible.');
  }

  void close() => _client.close();
}
