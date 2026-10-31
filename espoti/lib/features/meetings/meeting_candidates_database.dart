import 'package:latlong2/latlong.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'recommendation/recommendation_strategy.dart';

/// Candidate places of each meeting, in a relational SQLite database owned by
/// the vote screen (separate from AppDatabase, so neither schema depends on
/// the other). A place is stored once in `places`, even if it is a candidate
/// of many meetings; `meeting_candidates` links each meeting to its places in
/// order, which is the list a group vote will use.
class MeetingCandidatesDatabase {
  MeetingCandidatesDatabase._();

  static final instance = MeetingCandidatesDatabase._();

  Future<Database>? _database;

  Future<Database> get _db => _database ??= _open();

  Future<Database> _open() async => openDatabase(
        p.join(await getDatabasesPath(), 'espoti_candidates.db'),
        version: 1,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE places (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              category TEXT NOT NULL,
              lat REAL NOT NULL,
              lng REAL NOT NULL
            )''');
          await db.execute('''
            CREATE TABLE meeting_candidates (
              meeting_id TEXT NOT NULL,
              place_id TEXT NOT NULL REFERENCES places(id),
              rank INTEGER NOT NULL,
              PRIMARY KEY (meeting_id, place_id)
            )''');
        },
      );

  // The same place is the same name at the same point (~1 m).
  static String _placeId(PlaceCandidate place) => '${place.name}@'
      '${place.location.latitude.toStringAsFixed(5)},'
      '${place.location.longitude.toStringAsFixed(5)}';

  /// Replaces the candidate list of [meetingId] in a single transaction.
  Future<void> saveCandidates(
      String meetingId, List<PlaceCandidate> places) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete('meeting_candidates',
          where: 'meeting_id = ?', whereArgs: [meetingId]);
      final batch = txn.batch();
      for (var i = 0; i < places.length; i++) {
        final place = places[i];
        final placeId = _placeId(place);
        batch.insert(
          'places',
          {
            'id': placeId,
            'name': place.name,
            'category': place.category,
            'lat': place.location.latitude,
            'lng': place.location.longitude,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        batch.insert('meeting_candidates',
            {'meeting_id': meetingId, 'place_id': placeId, 'rank': i});
      }
      await batch.commit(noResult: true);
    });
  }

  /// Candidate places of [meetingId] in their original order.
  Future<List<PlaceCandidate>> candidatesOf(String meetingId) async {
    final rows = await (await _db).rawQuery('''
      SELECT p.name, p.category, p.lat, p.lng
      FROM meeting_candidates mc
      JOIN places p ON p.id = mc.place_id
      WHERE mc.meeting_id = ?
      ORDER BY mc.rank''', [meetingId]);
    return [
      for (final row in rows)
        PlaceCandidate(
          name: row['name'] as String,
          category: row['category'] as String,
          location: LatLng(
              (row['lat'] as num).toDouble(), (row['lng'] as num).toDouble()),
        ),
    ];
  }
}
