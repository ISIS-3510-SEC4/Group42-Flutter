import 'package:hive_ce/hive_ce.dart';
import 'package:latlong2/latlong.dart';

import 'recommendation/recommendation_strategy.dart';

/// Places found in a zone and when they were saved.
class StoredPlaces {
  const StoredPlaces(this.places, this.savedAt);

  final List<PlaceCandidate> places;
  final DateTime savedAt;
}

/// Places of each zone saved on disk with Hive (key/value, also works on the
/// web). Unlike the in-memory LRU, they survive closing the app, so the vote
/// screen can show real places when Overpass is unreachable.
class ZonePlacesStore {
  static const _boxName = 'places_by_zone';

  Future<Box<Map>> get _box => Hive.openBox<Map>(_boxName);

  Future<void> save(String zone, List<PlaceCandidate> places) async {
    final box = await _box;
    await box.put(zone, {
      'savedAt': DateTime.now().millisecondsSinceEpoch,
      'places': [
        for (final place in places)
          {
            'name': place.name,
            'category': place.category,
            'lat': place.location.latitude,
            'lng': place.location.longitude,
          },
      ],
    });
  }

  Future<StoredPlaces?> read(String zone) async {
    final entry = (await _box).get(zone);
    if (entry == null) return null;
    return StoredPlaces(
      [
        for (final place in entry['places'] as List)
          PlaceCandidate(
            name: place['name'] as String,
            category: place['category'] as String,
            location: LatLng(
                (place['lat'] as num).toDouble(), (place['lng'] as num).toDouble()),
          ),
      ],
      DateTime.fromMillisecondsSinceEpoch(entry['savedAt'] as int),
    );
  }
}
