import 'package:espoti/core/offline/local_store.dart';
import 'package:espoti/core/offline/pending_operation.dart';
import 'package:espoti/core/services/place_search_service.dart';
import 'package:espoti/models/meeting_record.dart';
import 'package:espoti/models/transit_mode.dart';
import 'package:espoti/models/user.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Feature 1 - Local Storage (User Profile Persistence)', () {
    test('User profile is saved and retrieved with full fields', () async {
      const user = AppUser(
        firstName: 'Carlos',
        lastName: 'Gomez',
        name: 'Carlos Gomez',
        phone: '3001234567',
        email: 'carlos@uniandes.edu.co',
        code: 'ANDES123',
        location: 'Bogotá, Colombia',
        preferences: ['Walk', 'Eat', 'Coffee'],
        maxRadiusKm: 15,
        avatarUrl: 'https://example.com/avatar.png',
        description: 'Estudiante de ingeniería',
      );

      final fetchedTs = DateTime(2026, 10, 30, 20, 0).millisecondsSinceEpoch;
      await LocalStore.instance.saveUserProfile(user, 'u_carlos', fetchedAt: fetchedTs);

      final loaded = await LocalStore.instance.getUserProfile('u_carlos');
      expect(loaded, isNotNull);
      expect(loaded!.name, 'Carlos Gomez');
      expect(loaded.phone, '3001234567');
      expect(loaded.email, 'carlos@uniandes.edu.co');
      expect(loaded.preferences, ['Walk', 'Eat', 'Coffee']);
      expect(loaded.maxRadiusKm, 15);

      final ts = await LocalStore.instance.getUserFetchedAt('u_carlos');
      expect(ts, fetchedTs);

      await LocalStore.instance.clearUserProfile('u_carlos');
      final cleared = await LocalStore.instance.getUserProfile('u_carlos');
      expect(cleared, isNull);
    });
  });

  group('Feature 1 - Local Storage (Meetings Persistence)', () {
    test('Meetings list is saved and retrieved locally', () async {
      final meeting = MeetingRecord(
        id: 'meet_99',
        organizerId: 'u_carlos',
        activity: 'Study session',
        dayLabel: 'Saturday',
        timeLabel: '4:00 PM',
        scheduledAt: DateTime(2026, 10, 31, 16, 0),
        transitMode: TransitMode.walking,
        budgetPerPerson: 25000,
        inviteeNames: const ['Laura', 'Sofia'],
        pointLat: 4.601,
        pointLng: -74.066,
        placeName: 'Biblioteca Mario Laserna',
        placeCategory: 'Lugar de estudio',
        status: MeetingRecord.scheduled,
        createdAtClient: 1000,
        updatedAtClient: 1000,
      );

      await LocalStore.instance.saveMeetings('u_carlos', [meeting]);

      final retrieved = await LocalStore.instance.getMeetings('u_carlos');
      expect(retrieved, hasLength(1));
      expect(retrieved.first.id, 'meet_99');
      expect(retrieved.first.placeName, 'Biblioteca Mario Laserna');
      expect(retrieved.first.transitMode, TransitMode.walking);
      expect(retrieved.first.budgetPerPerson, 25000);
      expect(retrieved.first.inviteeNames, ['Laura', 'Sofia']);
    });
  });

  group('Feature 1 - Local Storage (Recent Places & Cached Searches)', () {
    test('PlaceSuggestion serialization and equality', () {
      const place = PlaceSuggestion(
        title: 'Café Valenzuela',
        subtitle: 'Cra 1 #19-20, Bogotá',
        point: LatLng(4.602, -74.065),
      );

      final json = place.toJson();
      final restored = PlaceSuggestion.fromJson(json);

      expect(restored.title, place.title);
      expect(restored.subtitle, place.subtitle);
      expect(restored.point.latitude, place.point.latitude);
      expect(restored.point.longitude, place.point.longitude);
      expect(restored, equals(place));
    });

    test('Recent places can be saved and queried', () async {
      const p1 = PlaceSuggestion(
        title: 'Parque de los Periodistas',
        subtitle: 'La Candelaria, Bogotá',
        point: LatLng(4.6015, -74.069),
      );

      await LocalStore.instance.saveRecentPlace(p1, query: 'periodistas');

      final cached = await LocalStore.instance.searchCachedPlaces('periodistas');
      expect(cached, isNotEmpty);
      expect(cached.first.title, contains('Periodistas'));

      await LocalStore.instance.clearRecentPlaces();
      final empty = await LocalStore.instance.getRecentPlaces();
      expect(empty, isEmpty);
    });
  });

  group('Feature 1 - Local Storage (Pending Offline Operations Outbox)', () {
    test('Pending transactions are persisted and can be managed', () async {
      final op1 = PendingOperation.create(
        kind: PendingWriteKind.upsert,
        collection: 'users',
        docId: 'u1',
        ownerUid: 'u1',
        data: {'name': 'Updated Name'},
      );

      final op2 = PendingOperation.create(
        kind: PendingWriteKind.upsert,
        collection: 'meetings',
        docId: 'm1',
        ownerUid: 'u1',
        data: {'status': 'canceled'},
      );

      await LocalStore.instance.savePendingOperations([op1, op2], isDeadLetter: false);

      final pending = await LocalStore.instance.getPendingOperations(deadLetterOnly: false);
      expect(pending, hasLength(2));
      expect(pending.any((o) => o.collection == 'users'), isTrue);
      expect(pending.any((o) => o.collection == 'meetings'), isTrue);

      await LocalStore.instance.savePendingOperations([], isDeadLetter: false);
      final cleared = await LocalStore.instance.getPendingOperations(deadLetterOnly: false);
      expect(cleared, isEmpty);
    });
  });
}
