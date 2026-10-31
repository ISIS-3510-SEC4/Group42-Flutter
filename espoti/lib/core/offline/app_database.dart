import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../models/meeting_record.dart';
import '../../models/transit_mode.dart';
import '../../models/user.dart';
import '../services/place_search_service.dart';
import 'pending_operation.dart';

/// Central SQLite Database management for Espoti (Sprint 3 - Feature 1).
///
/// Provides structured persistence for:
/// - User profiles and freshness timestamps
/// - Meeting records and user agendas
/// - Recent places and search suggestions cache
/// - Pending offline transactions (Outbox Queue)
/// - Generic key-value store for auxiliary data
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const String _dbName = 'espoti_local.db';
  static const int _dbVersion = 1;

  Database? _db;
  bool _initFailed = false;

  /// Returns the active SQLite database, lazily initializing it if needed.
  Future<Database?> get database async {
    if (_initFailed) return null;
    if (_db != null && _db!.isOpen) return _db;
    try {
      _db = await _initDatabase();
      return _db;
    } catch (e) {
      debugPrint('AppDatabase: initialization error, using in-memory/preferences fallback: $e');
      _initFailed = true;
      return null;
    }
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final dbPath = p.join(databasesPath, _dbName);

    return await openDatabase(
      dbPath,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    // 1. User Profiles
    batch.execute('''
      CREATE TABLE user_profiles (
        uid TEXT PRIMARY KEY,
        firstName TEXT,
        lastName TEXT,
        name TEXT,
        phone TEXT,
        email TEXT,
        code TEXT,
        location TEXT,
        preferences TEXT,
        maxRadiusKm INTEGER,
        avatarUrl TEXT,
        description TEXT,
        fetchedAt INTEGER,
        updatedAt INTEGER
      )
    ''');

    // 2. Meeting Records
    batch.execute('''
      CREATE TABLE meetings (
        id TEXT PRIMARY KEY,
        organizerId TEXT NOT NULL,
        activity TEXT NOT NULL,
        dayLabel TEXT NOT NULL,
        timeLabel TEXT NOT NULL,
        scheduledAt INTEGER,
        transitMode TEXT,
        budgetPerPerson INTEGER,
        inviteeNames TEXT,
        pointLat REAL,
        pointLng REAL,
        placeName TEXT,
        placeCategory TEXT,
        status TEXT NOT NULL,
        createdAtClient INTEGER NOT NULL,
        updatedAtClient INTEGER NOT NULL,
        fetchedAt INTEGER
      )
    ''');
    batch.execute('CREATE INDEX idx_meetings_organizer ON meetings(organizerId)');

    // 3. Recent Places & Search Queries Cache
    batch.execute('''
      CREATE TABLE recent_places (
        id TEXT PRIMARY KEY,
        query TEXT,
        title TEXT NOT NULL,
        subtitle TEXT NOT NULL,
        lat REAL NOT NULL,
        lng REAL NOT NULL,
        category TEXT,
        searchedAt INTEGER NOT NULL
      )
    ''');
    batch.execute('CREATE INDEX idx_recent_places_query ON recent_places(query)');
    batch.execute('CREATE INDEX idx_recent_places_searchedAt ON recent_places(searchedAt DESC)');

    // 4. Pending Transactions (Outbox for Offline-first Sync)
    batch.execute('''
      CREATE TABLE pending_transactions (
        id TEXT PRIMARY KEY,
        kind TEXT NOT NULL,
        collection TEXT NOT NULL,
        docId TEXT NOT NULL,
        ownerUid TEXT NOT NULL,
        data TEXT NOT NULL,
        dataIfMissing TEXT,
        clientUpdatedAt INTEGER NOT NULL,
        checkConflict INTEGER NOT NULL DEFAULT 0,
        attempts INTEGER NOT NULL DEFAULT 0,
        lastError TEXT,
        isDeadLetter INTEGER NOT NULL DEFAULT 0
      )
    ''');
    batch.execute('CREATE INDEX idx_pending_tx_owner ON pending_transactions(ownerUid)');
    batch.execute('CREATE INDEX idx_pending_tx_doc ON pending_transactions(collection, docId)');

    // 5. General Key-Value Storage
    batch.execute('''
      CREATE TABLE key_value_store (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updatedAt INTEGER NOT NULL
      )
    ''');

    await batch.commit(noResult: true);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Migrations for future database versions
  }

  // ===========================================================================
  // USER PROFILES
  // ===========================================================================

  Future<void> saveUserProfile(AppUser user, String uid, {int? fetchedAt}) async {
    final db = await database;
    if (db == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert(
      'user_profiles',
      {
        'uid': uid,
        'firstName': user.firstName,
        'lastName': user.lastName,
        'name': user.name,
        'phone': user.phone,
        'email': user.email,
        'code': user.code,
        'location': user.location,
        'preferences': jsonEncode(user.preferences),
        'maxRadiusKm': user.maxRadiusKm,
        'avatarUrl': user.avatarUrl,
        'description': user.description,
        'fetchedAt': fetchedAt ?? now,
        'updatedAt': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<AppUser?> getUserProfile(String uid) async {
    final db = await database;
    if (db == null) return null;

    final rows = await db.query(
      'user_profiles',
      where: 'uid = ?',
      whereArgs: [uid],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final row = rows.first;
    List<String> prefs = const ['Walk', 'Eat'];
    try {
      if (row['preferences'] is String) {
        final decoded = jsonDecode(row['preferences'] as String);
        if (decoded is List) {
          prefs = decoded.map((e) => e.toString()).toList();
        }
      }
    } catch (_) {}

    return AppUser(
      firstName: row['firstName'] as String? ?? '',
      lastName: row['lastName'] as String? ?? '',
      name: row['name'] as String? ?? '',
      phone: row['phone'] as String? ?? '',
      email: row['email'] as String? ?? '',
      code: row['code'] as String? ?? '',
      location: row['location'] as String? ?? '',
      preferences: prefs,
      maxRadiusKm: row['maxRadiusKm'] as int? ?? 10,
      avatarUrl: row['avatarUrl'] as String? ?? '',
      description: row['description'] as String? ?? '',
    );
  }

  Future<int?> getUserFetchedAt(String uid) async {
    final db = await database;
    if (db == null) return null;

    final rows = await db.query(
      'user_profiles',
      columns: ['fetchedAt'],
      where: 'uid = ?',
      whereArgs: [uid],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['fetchedAt'] as int?;
  }

  Future<void> saveUserFetchedAt(String uid, int timestamp) async {
    final db = await database;
    if (db == null) return;

    await db.update(
      'user_profiles',
      {'fetchedAt': timestamp},
      where: 'uid = ?',
      whereArgs: [uid],
    );
  }

  Future<void> deleteUserProfile(String uid) async {
    final db = await database;
    if (db == null) return;
    await db.delete('user_profiles', where: 'uid = ?', whereArgs: [uid]);
  }

  // ===========================================================================
  // MEETINGS
  // ===========================================================================

  Future<void> saveMeetings(String uid, List<MeetingRecord> meetings, {DateTime? fetchedAt}) async {
    final db = await database;
    if (db == null) return;

    final fetchedTs = fetchedAt?.millisecondsSinceEpoch;
    final batch = db.batch();

    // Remove existing local records for this organizer that are not in the new batch
    final keepIds = meetings.map((m) => m.id).toList();
    if (keepIds.isNotEmpty) {
      final placeholders = List.filled(keepIds.length, '?').join(',');
      batch.delete(
        'meetings',
        where: 'organizerId = ? AND id NOT IN ($placeholders)',
        whereArgs: [uid, ...keepIds],
      );
    } else {
      batch.delete('meetings', where: 'organizerId = ?', whereArgs: [uid]);
    }

    for (final m in meetings) {
      batch.insert(
        'meetings',
        {
          'id': m.id,
          'organizerId': m.organizerId,
          'activity': m.activity,
          'dayLabel': m.dayLabel,
          'timeLabel': m.timeLabel,
          'scheduledAt': m.scheduledAt?.millisecondsSinceEpoch,
          'transitMode': m.transitMode?.name,
          'budgetPerPerson': m.budgetPerPerson,
          'inviteeNames': jsonEncode(m.inviteeNames),
          'pointLat': m.pointLat,
          'pointLng': m.pointLng,
          'placeName': m.placeName,
          'placeCategory': m.placeCategory,
          'status': m.status,
          'createdAtClient': m.createdAtClient,
          'updatedAtClient': m.updatedAtClient,
          'fetchedAt': fetchedTs,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  Future<List<MeetingRecord>> getMeetings(String uid) async {
    final db = await database;
    if (db == null) return [];

    final rows = await db.query(
      'meetings',
      where: 'organizerId = ?',
      whereArgs: [uid],
      orderBy: 'COALESCE(scheduledAt, createdAtClient) DESC',
    );

    return rows.map((r) => _meetingFromRow(r)).whereType<MeetingRecord>().toList();
  }

  Future<MeetingRecord?> getMeetingById(String id) async {
    final db = await database;
    if (db == null) return null;

    final rows = await db.query(
      'meetings',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _meetingFromRow(rows.first);
  }

  MeetingRecord? _meetingFromRow(Map<String, Object?> r) {
    try {
      List<String> invitees = [];
      if (r['inviteeNames'] is String) {
        final decoded = jsonDecode(r['inviteeNames'] as String);
        if (decoded is List) invitees = decoded.map((e) => e.toString()).toList();
      }

      TransitMode? mode;
      final modeStr = r['transitMode'] as String?;
      if (modeStr != null && modeStr.isNotEmpty) {
        mode = TransitMode.values.cast<TransitMode?>().firstWhere(
              (m) => m?.name == modeStr,
              orElse: () => null,
            );
      }

      final scheduledTs = r['scheduledAt'] as int?;

      return MeetingRecord(
        id: r['id'] as String,
        organizerId: r['organizerId'] as String,
        activity: r['activity'] as String,
        dayLabel: r['dayLabel'] as String,
        timeLabel: r['timeLabel'] as String,
        scheduledAt: scheduledTs != null ? DateTime.fromMillisecondsSinceEpoch(scheduledTs) : null,
        transitMode: mode,
        budgetPerPerson: r['budgetPerPerson'] as int?,
        inviteeNames: invitees,
        pointLat: (r['pointLat'] as num?)?.toDouble(),
        pointLng: (r['pointLng'] as num?)?.toDouble(),
        placeName: r['placeName'] as String?,
        placeCategory: r['placeCategory'] as String?,
        status: r['status'] as String? ?? MeetingRecord.planning,
        createdAtClient: r['createdAtClient'] as int? ?? 0,
        updatedAtClient: r['updatedAtClient'] as int? ?? 0,
      );
    } catch (e) {
      debugPrint('AppDatabase: error parsing meeting row: $e');
      return null;
    }
  }

  // ===========================================================================
  // RECENT PLACES & CACHED SEARCHES
  // ===========================================================================

  Future<void> saveRecentPlace(PlaceSuggestion place, {String? query, String? category}) async {
    final db = await database;
    if (db == null) return;

    final id = '${place.point.latitude.toStringAsFixed(5)}_${place.point.longitude.toStringAsFixed(5)}_${place.title}';
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.insert(
      'recent_places',
      {
        'id': id,
        'query': query?.trim().toLowerCase(),
        'title': place.title,
        'subtitle': place.subtitle,
        'lat': place.point.latitude,
        'lng': place.point.longitude,
        'category': category,
        'searchedAt': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<PlaceSuggestion>> getRecentPlaces({int limit = 10}) async {
    final db = await database;
    if (db == null) return [];

    final rows = await db.query(
      'recent_places',
      orderBy: 'searchedAt DESC',
      limit: limit,
    );

    return rows.map((r) => _placeFromRow(r)).whereType<PlaceSuggestion>().toList();
  }

  Future<List<PlaceSuggestion>> searchCachedPlaces(String query, {int limit = 10}) async {
    final db = await database;
    if (db == null) return [];

    final cleanQuery = query.trim().toLowerCase();
    final rows = await db.query(
      'recent_places',
      where: 'query LIKE ? OR title LIKE ? OR subtitle LIKE ?',
      whereArgs: ['%$cleanQuery%', '%$cleanQuery%', '%$cleanQuery%'],
      orderBy: 'searchedAt DESC',
      limit: limit,
    );

    return rows.map((r) => _placeFromRow(r)).whereType<PlaceSuggestion>().toList();
  }

  PlaceSuggestion? _placeFromRow(Map<String, Object?> r) {
    try {
      final lat = (r['lat'] as num?)?.toDouble();
      final lng = (r['lng'] as num?)?.toDouble();
      final title = r['title'] as String?;
      final subtitle = r['subtitle'] as String? ?? '';
      if (lat == null || lng == null || title == null) return null;

      return PlaceSuggestion(
        title: title,
        subtitle: subtitle,
        point: LatLng(lat, lng),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clearRecentPlaces() async {
    final db = await database;
    if (db == null) return;
    await db.delete('recent_places');
  }

  // ===========================================================================
  // PENDING TRANSACTIONS (SYNC OUTBOX)
  // ===========================================================================

  Future<void> savePendingTransactions(List<PendingOperation> ops, {bool isDeadLetter = false}) async {
    final db = await database;
    if (db == null) return;

    final batch = db.batch();
    for (final op in ops) {
      batch.insert(
        'pending_transactions',
        {
          'id': op.id,
          'kind': op.kind.name,
          'collection': op.collection,
          'docId': op.docId,
          'ownerUid': op.ownerUid,
          'data': jsonEncode(op.data),
          'dataIfMissing': jsonEncode(op.dataIfMissing),
          'clientUpdatedAt': op.clientUpdatedAt,
          'checkConflict': op.checkConflict ? 1 : 0,
          'attempts': op.attempts,
          'lastError': op.lastError,
          'isDeadLetter': isDeadLetter ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<PendingOperation>> getPendingTransactions({bool deadLetterOnly = false}) async {
    final db = await database;
    if (db == null) return [];

    final rows = await db.query(
      'pending_transactions',
      where: 'isDeadLetter = ?',
      whereArgs: [deadLetterOnly ? 1 : 0],
      orderBy: 'clientUpdatedAt ASC',
    );

    return rows.map((r) => _pendingOpFromRow(r)).whereType<PendingOperation>().toList();
  }

  Future<void> deletePendingTransaction(String id) async {
    final db = await database;
    if (db == null) return;
    await db.delete('pending_transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearPendingTransactions({bool deadLetterOnly = false}) async {
    final db = await database;
    if (db == null) return;
    await db.delete(
      'pending_transactions',
      where: 'isDeadLetter = ?',
      whereArgs: [deadLetterOnly ? 1 : 0],
    );
  }

  PendingOperation? _pendingOpFromRow(Map<String, Object?> r) {
    try {
      final kindStr = r['kind'] as String?;
      final kind = kindStr == PendingWriteKind.createOnce.name
          ? PendingWriteKind.createOnce
          : PendingWriteKind.upsert;

      final dataStr = r['data'] as String? ?? '{}';
      final dataMissingStr = r['dataIfMissing'] as String? ?? '{}';

      return PendingOperation(
        id: r['id'] as String,
        kind: kind,
        collection: r['collection'] as String,
        docId: r['docId'] as String,
        ownerUid: r['ownerUid'] as String,
        data: Map<String, dynamic>.from(jsonDecode(dataStr) as Map),
        dataIfMissing: Map<String, dynamic>.from(jsonDecode(dataMissingStr) as Map),
        clientUpdatedAt: r['clientUpdatedAt'] as int? ?? 0,
        checkConflict: (r['checkConflict'] as int? ?? 0) == 1,
        attempts: r['attempts'] as int? ?? 0,
        lastError: r['lastError'] as String?,
      );
    } catch (e) {
      debugPrint('AppDatabase: error parsing pending op: $e');
      return null;
    }
  }

  // ===========================================================================
  // KEY-VALUE STORE
  // ===========================================================================

  Future<String?> getKvString(String key) async {
    final db = await database;
    if (db == null) return null;

    final rows = await db.query(
      'key_value_store',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> setKvString(String key, String value) async {
    final db = await database;
    if (db == null) return;

    await db.insert(
      'key_value_store',
      {
        'key': key,
        'value': value,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeKvKey(String key) async {
    final db = await database;
    if (db == null) return;
    await db.delete('key_value_store', where: 'key = ?', whereArgs: [key]);
  }

  // ===========================================================================
  // LAST KNOWN GPS LOCATION
  // ===========================================================================

  Future<void> saveLastLocation(double lat, double lng) async {
    await setKvString('last_known_gps_lat', lat.toString());
    await setKvString('last_known_gps_lng', lng.toString());
  }

  Future<Map<String, double>?> getLastLocation() async {
    final latStr = await getKvString('last_known_gps_lat');
    final lngStr = await getKvString('last_known_gps_lng');
    if (latStr == null || lngStr == null) return null;
    final lat = double.tryParse(latStr);
    final lng = double.tryParse(lngStr);
    if (lat == null || lng == null) return null;
    return {'lat': lat, 'lng': lng};
  }
}
