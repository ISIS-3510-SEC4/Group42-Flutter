import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// Multithreading / Concurrency engine for heavy GPS and routing calculations (Sprint 3 - Feature 3).
///
/// Runs intensive geometric, distance, and routing algorithms in background Dart Isolates
/// to keep the main UI thread at 60 fps.
class GeoIsolate {
  GeoIsolate._();

  /// Calculates the geographical centroid of a list of coordinates in a Dart Isolate.
  static Future<LatLng?> computeCentroid(List<LatLng> points) async {
    if (points.isEmpty) return null;
    if (points.length == 1) return points.first;
    if (kIsWeb) return _calculateCentroidSync(points);

    final rawPoints = points.map((p) => [p.latitude, p.longitude]).toList();
    final result = await compute(_centroidWorker, rawPoints, debugLabel: 'geo-isolate-centroid');
    if (result == null) return null;
    return LatLng(result[0], result[1]);
  }

  /// Calculates fair-travel rankings and distances for candidates and participants in an Isolate.
  static Future<List<Map<String, dynamic>>> rankPlacesFairTravel({
    required List<Map<String, dynamic>> rawCandidates,
    required List<Map<String, dynamic>> rawParticipants,
  }) async {
    if (rawCandidates.isEmpty || rawParticipants.isEmpty) return [];

    final payload = {
      'candidates': rawCandidates,
      'participants': rawParticipants,
    };

    if (kIsWeb) return _fairTravelRankingWorker(payload);

    return compute(_fairTravelRankingWorker, payload, debugLabel: 'geo-isolate-fair-ranking');
  }

  /// Parses OSRM GeoJSON route response and generates points list in an Isolate.
  static Future<Map<String, dynamic>?> parseOsrmRoute(String rawJson) async {
    if (rawJson.isEmpty) return null;
    if (kIsWeb) return _osrmRouteWorker(rawJson);

    return compute(_osrmRouteWorker, rawJson, debugLabel: 'geo-isolate-osrm-parser');
  }

  /// Filters candidates within a bounding radius (meters) using Haversine formula in an Isolate.
  static Future<List<Map<String, dynamic>>> filterCandidatesWithinRadius({
    required List<Map<String, dynamic>> candidates,
    required LatLng center,
    required double radiusMeters,
  }) async {
    if (candidates.isEmpty) return [];

    final payload = {
      'candidates': candidates,
      'centerLat': center.latitude,
      'centerLng': center.longitude,
      'radius': radiusMeters,
    };

    if (kIsWeb) return _filterRadiusWorker(payload);

    return compute(_filterRadiusWorker, payload, debugLabel: 'geo-isolate-filter-radius');
  }

  static LatLng? _calculateCentroidSync(List<LatLng> points) {
    if (points.isEmpty) return null;
    double latSum = 0;
    double lngSum = 0;
    for (final p in points) {
      latSum += p.latitude;
      lngSum += p.longitude;
    }
    return LatLng(latSum / points.length, lngSum / points.length);
  }
}

// =============================================================================
// TOP-LEVEL WORKERS FOR ISOLATES
// =============================================================================

List<double>? _centroidWorker(List<List<double>> rawPoints) {
  if (rawPoints.isEmpty) return null;
  double sumLat = 0;
  double sumLng = 0;
  for (final p in rawPoints) {
    sumLat += p[0];
    sumLng += p[1];
  }
  return [sumLat / rawPoints.length, sumLng / rawPoints.length];
}

List<Map<String, dynamic>> _fairTravelRankingWorker(Map<String, dynamic> payload) {
  final candidates = (payload['candidates'] as List).cast<Map<String, dynamic>>();
  final participants = (payload['participants'] as List).cast<Map<String, dynamic>>();

  final results = <Map<String, dynamic>>[];

  for (final candidate in candidates) {
    final cLat = (candidate['lat'] as num).toDouble();
    final cLng = (candidate['lng'] as num).toDouble();

    final distances = <double>[];
    for (final participant in participants) {
      final pLat = (participant['lat'] as num).toDouble();
      final pLng = (participant['lng'] as num).toDouble();
      distances.add(_haversineDistance(cLat, cLng, pLat, pLng));
    }

    if (distances.isEmpty) continue;

    double maxDist = distances.reduce(math.max);
    double minDist = distances.reduce(math.min);
    double sum = distances.reduce((a, b) => a + b);
    double mean = sum / distances.length;

    double varianceSum = 0;
    for (final d in distances) {
      varianceSum += (d - mean) * (d - mean);
    }
    double stdDev = math.sqrt(varianceSum / distances.length);
    double score = maxDist + stdDev;

    results.add({
      'candidate': candidate,
      'score': score,
      'maxDistance': maxDist,
      'minDistance': minDist,
      'stdDev': stdDev,
    });
  }

  // Sort ascending by score (fair travel best score is lowest)
  results.sort((a, b) => (a['score'] as double).compareTo(b['score'] as double));
  return results;
}

Map<String, dynamic>? _osrmRouteWorker(String rawJson) {
  try {
    final data = jsonDecode(rawJson) as Map<String, dynamic>;
    if (data['code'] != 'Ok' || data['routes'] == null) return null;
    final routes = data['routes'] as List;
    if (routes.isEmpty) return null;

    final route = routes.first as Map<String, dynamic>;
    final distanceMeters = (route['distance'] as num).toDouble();
    final durationSeconds = (route['duration'] as num).toDouble();
    final geometry = route['geometry'] as Map<String, dynamic>;
    final coordinates = geometry['coordinates'] as List;

    final points = <List<double>>[];
    for (final coord in coordinates) {
      if (coord is List && coord.length >= 2) {
        final lng = (coord[0] as num).toDouble();
        final lat = (coord[1] as num).toDouble();
        points.add([lat, lng]);
      }
    }

    return {
      'points': points,
      'distanceMeters': distanceMeters,
      'durationSeconds': durationSeconds,
    };
  } catch (e) {
    return null;
  }
}

List<Map<String, dynamic>> _filterRadiusWorker(Map<String, dynamic> payload) {
  final candidates = (payload['candidates'] as List).cast<Map<String, dynamic>>();
  final centerLat = payload['centerLat'] as double;
  final centerLng = payload['centerLng'] as double;
  final radius = payload['radius'] as double;

  final filtered = <Map<String, dynamic>>[];
  for (final c in candidates) {
    final lat = (c['lat'] as num).toDouble();
    final lng = (c['lng'] as num).toDouble();
    final dist = _haversineDistance(centerLat, centerLng, lat, lng);
    if (dist <= radius) {
      filtered.add({...c, 'distanceMeters': dist});
    }
  }
  return filtered;
}

double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
  const earthRadius = 6371000.0; // meters
  final dLat = _degToRad(lat2 - lat1);
  final dLon = _degToRad(lon2 - lon1);

  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_degToRad(lat1)) *
          math.cos(_degToRad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);

  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadius * c;
}

double _degToRad(double degrees) => degrees * (math.pi / 180.0);
