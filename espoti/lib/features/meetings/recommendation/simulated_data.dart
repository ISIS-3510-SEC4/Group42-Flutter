import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'recommendation_strategy.dart';

/// Group for the meeting: the user (GPS, or the chosen point as fallback)
/// plus two simulated friends placed at fixed offsets from that point.
Future<List<Participant>> loadParticipants(LatLng chosenPoint) async {
  return [
    Participant(name: 'Tú', location: await _userLocation(chosenPoint)),
    Participant(
      name: 'Ana',
      location: LatLng(chosenPoint.latitude + 0.020, chosenPoint.longitude + 0.012),
    ),
    Participant(
      name: 'Luis',
      location: LatLng(chosenPoint.latitude - 0.015, chosenPoint.longitude + 0.025),
    ),
  ];
}

Future<LatLng> _userLocation(LatLng fallback) async {
  try {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return fallback;
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 5),
      ),
    );
    return LatLng(position.latitude, position.longitude);
  } catch (_) {
    return fallback;
  }
}

/// Placeholder places used only when the places service is unavailable.
List<PlaceCandidate> samplePlacesAround(LatLng center) {
  const offsets = [
    ('Café de ejemplo Norte', 'Cafetería', 0.010, 0.002),
    ('Restaurante de ejemplo Este', 'Restaurante', 0.002, 0.015),
    ('Bar de ejemplo Sur', 'Bar', -0.012, 0.008),
    ('Café de ejemplo Centro', 'Cafetería', 0.004, 0.010),
    ('Restaurante de ejemplo Oeste', 'Restaurante', 0.000, -0.012),
    ('Comida rápida de ejemplo', 'Comida rápida', 0.018, 0.020),
    ('Bar de ejemplo Noreste', 'Bar', 0.022, 0.016),
    ('Café de ejemplo Sureste', 'Cafetería', -0.008, 0.020),
    ('Parque de ejemplo Central', outdoorCategory, 0.006, 0.008),
    ('Parque de ejemplo Sur', outdoorCategory, -0.006, 0.014),
  ];
  return [
    for (final (name, category, dLat, dLon) in offsets)
      PlaceCandidate(
        name: name,
        category: category,
        location: LatLng(center.latitude + dLat, center.longitude + dLon),
      ),
  ];
}
