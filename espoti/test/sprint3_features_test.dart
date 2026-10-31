import 'package:espoti/core/analytics/analytics_repository.dart';
import 'package:espoti/core/analytics/recommendation_acceptance_tracker.dart';
import 'package:espoti/core/concurrency/geo_isolate.dart';
import 'package:espoti/core/offline/local_store.dart';
import 'package:espoti/core/offline/sync_queue.dart';
import 'package:espoti/models/analytics_event.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAnalyticsRepo implements AnalyticsRepository {
  final List<AnalyticsEvent> events = [];

  @override
  Future<void> saveEvent(AnalyticsEvent event) async {
    events.add(event);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Sprint 3 - Area 1: BQ 5 Analytics Pipeline & Tracker', () {
    test('RecommendationAcceptanceTracker logs accepted decision with rich metadata', () async {
      final mockRepo = _MockAnalyticsRepo();
      final tracker = RecommendationAcceptanceTracker(
        repository: mockRepo,
        sessionId: 'session-test-1',
      );

      await tracker.recordAccepted(
        userId: 'user_123',
        placeId: 'place_cafe_bogota',
        placeName: 'Café San Alberto',
        placeCategory: 'Cafetería',
        locationPreferences: ['Walk', 'Cafe'],
        maxRadiusKm: 5,
        distanceMeters: 450.0,
        interactionPattern: RecommendationInteractionPattern.detailsViewed,
        durationMs: 3200,
      );

      expect(mockRepo.events, hasLength(1));
      final event = mockRepo.events.first;
      expect(event.eventType, AnalyticsEventType.recommendationDecision);
      expect(event.userId, 'user_123');
      expect(event.platform, 'FLUTTER');
      expect(event.metadata['accepted'], isTrue);
      expect(event.metadata['interactionPattern'], 'DETAILS_VIEWED');
      expect(event.metadata['locationPreferences'], ['Walk', 'Cafe']);
      expect(event.metadata['distanceMeters'], 450.0);
    });

    test('RecommendationAcceptanceTracker logs rejected decision', () async {
      final mockRepo = _MockAnalyticsRepo();
      final tracker = RecommendationAcceptanceTracker(
        repository: mockRepo,
        sessionId: 'session-test-2',
      );

      await tracker.recordRejected(
        userId: 'user_456',
        placeId: 'place_park_far',
        placeName: 'Parque Simón Bolívar',
        placeCategory: 'Parque',
        locationPreferences: ['Eat'],
        maxRadiusKm: 2,
        distanceMeters: 8500.0,
        interactionPattern: RecommendationInteractionPattern.mapExpanded,
      );

      expect(mockRepo.events, hasLength(1));
      final event = mockRepo.events.first;
      expect(event.metadata['accepted'], isFalse);
      expect(event.metadata['interactionPattern'], 'MAP_EXPANDED');
    });
  });

  group('Sprint 3 - Area 3 & 6: Local Storage & Persistence', () {
    test('Persists and retrieves user last known GPS coordinates', () async {
      await LocalStore.instance.saveLastLocation(4.6025, -74.0682);

      final loc = await LocalStore.instance.getLastLocation();
      expect(loc, isNotNull);
      expect(loc!['lat'], closeTo(4.6025, 0.0001));
      expect(loc['lng'], closeTo(-74.0682, 0.0001));
    });
  });

  group('Sprint 3 - Area 4: Eventual Connectivity & SyncQueue', () {
    test('SyncQueue queues profile updates correctly', () async {
      final queue = SyncQueue.instance;
      await queue.enqueueProfileUpdate(
        uid: 'user_test_sync',
        data: {'name': 'Camila Restrepo', 'phone': '3119876543'},
      );

      final pending = await queue.getPendingOperations();
      expect(pending.any((o) => o.collection == 'users' && o.docId == 'user_test_sync'), isTrue);
    });
  });

  group('Sprint 3 - Area 5: Multithreading & Isolates (GeoIsolate)', () {
    test('Computes geographical centroid accurately', () async {
      final points = [
        const LatLng(4.0, -74.0),
        const LatLng(5.0, -74.0),
        const LatLng(4.5, -73.0),
        const LatLng(4.5, -75.0),
      ];

      final centroid = await GeoIsolate.computeCentroid(points);
      expect(centroid, isNotNull);
      expect(centroid!.latitude, closeTo(4.5, 0.01));
      expect(centroid.longitude, closeTo(-74.0, 0.01));
    });

    test('Parses OSRM route payload in isolate worker', () async {
      const mockOsrmJson = '''
      {
        "code": "Ok",
        "routes": [
          {
            "distance": 3520.5,
            "duration": 650.0,
            "geometry": {
              "coordinates": [
                [-74.068, 4.602],
                [-74.067, 4.603],
                [-74.066, 4.604]
              ]
            }
          }
        ]
      }
      ''';

      final parsed = await GeoIsolate.parseOsrmRoute(mockOsrmJson);
      expect(parsed, isNotNull);
      expect(parsed!['distanceMeters'], closeTo(3520.5, 0.1));
      final points = parsed['points'] as List;
      expect(points, hasLength(3));
      expect(points.first[0], closeTo(4.602, 0.001));
      expect(points.first[1], closeTo(-74.068, 0.001));
    });
  });
}
