import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/meeting_record.dart';
import '../../models/user.dart';
import '../concurrency/json_isolate.dart';
import '../services/place_search_service.dart';
import 'app_database.dart';
import 'pending_operation.dart';

/// Layer for local persistence and offline-first storage (Sprint 3 - Feature 1).
///
/// Combines SQLite structured tables via [AppDatabase] with fallback and KV support
/// through [SharedPreferences].
class LocalStore {
  LocalStore._();

  /// Singleton instance of LocalStore.
  static final LocalStore instance = LocalStore._();

  /// Keys for legacy/KV sync operations.
  static const String outboxKey = 'espoti_sync_outbox_v1';
  static const String deadLetterKey = 'espoti_sync_failed_v1';
  static String userProfileKey(String uid) => 'espoti_user_profile_$uid';
  static String userFetchedAtKey(String uid) => 'espoti_user_fetched_at_$uid';
  static String meetingsKey(String uid) => 'espoti_meetings_v1_$uid';

  AppDatabase get _db => AppDatabase.instance;
  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  // ===========================================================================
  // DOMAIN STORAGE: USER PROFILES
  // ===========================================================================

  /// Persists a user profile to SQLite and updates SharedPreferences mirror.
  Future<void> saveUserProfile(AppUser user, String uid, {int? fetchedAt}) async {
    try {
      await _db.saveUserProfile(user, uid, fetchedAt: fetchedAt);
    } catch (e) {
      debugPrint('LocalStore: SQLite saveUserProfile error: $e');
    }
    // Mirror in JSON store for backwards compatibility
    await writeJson(userProfileKey(uid), user.toJson());
    if (fetchedAt != null) {
      await writeInt(userFetchedAtKey(uid), fetchedAt);
    }
  }

  /// Retrieves a user profile, checking SQLite first, then KV store.
  Future<AppUser?> getUserProfile(String uid) async {
    try {
      final fromDb = await _db.getUserProfile(uid);
      if (fromDb != null) return fromDb;
    } catch (e) {
      debugPrint('LocalStore: SQLite getUserProfile fallback: $e');
    }

    final raw = await readJson(userProfileKey(uid));
    if (raw is Map) {
      return AppUser.fromJson(Map<String, dynamic>.from(raw));
    }
    return null;
  }

  Future<int?> getUserFetchedAt(String uid) async {
    try {
      final fromDb = await _db.getUserFetchedAt(uid);
      if (fromDb != null) return fromDb;
    } catch (_) {}
    return readInt(userFetchedAtKey(uid));
  }

  Future<void> saveUserFetchedAt(String uid, int timestamp) async {
    try {
      await _db.saveUserFetchedAt(uid, timestamp);
    } catch (_) {}
    await writeInt(userFetchedAtKey(uid), timestamp);
  }

  Future<void> clearUserProfile(String uid) async {
    try {
      await _db.deleteUserProfile(uid);
    } catch (_) {}
    await remove(userProfileKey(uid));
    await remove(userFetchedAtKey(uid));
  }

  // ===========================================================================
  // DOMAIN STORAGE: MEETINGS
  // ===========================================================================

  /// Persists a user's meetings list to SQLite and updates the JSON snapshot.
  Future<void> saveMeetings(
    String uid,
    List<MeetingRecord> meetings, {
    DateTime? fetchedAt,
  }) async {
    try {
      await _db.saveMeetings(uid, meetings, fetchedAt: fetchedAt);
    } catch (e) {
      debugPrint('LocalStore: SQLite saveMeetings error: $e');
    }

    await writeJson(meetingsKey(uid), {
      'fetchedAt': fetchedAt?.millisecondsSinceEpoch ?? 0,
      'records': meetings.map((r) => r.toJson()).toList(),
    });
  }

  /// Retrieves user meetings from SQLite, falling back to JSON snapshot.
  Future<List<MeetingRecord>> getMeetings(String uid) async {
    try {
      final fromDb = await _db.getMeetings(uid);
      if (fromDb.isNotEmpty) return fromDb;
    } catch (e) {
      debugPrint('LocalStore: SQLite getMeetings error: $e');
    }

    final raw = await readJson(meetingsKey(uid));
    if (raw is Map && raw['records'] is List) {
      final list = raw['records'] as List;
      final result = <MeetingRecord>[];
      for (final item in list) {
        if (item is Map) {
          final m = MeetingRecord.tryFromMap(Map<String, dynamic>.from(item));
          if (m != null) result.add(m);
        }
      }
      return result;
    }
    return [];
  }

  // ===========================================================================
  // DOMAIN STORAGE: RECENT PLACES & CACHED SEARCHES
  // ===========================================================================

  /// Saves a place suggestion into the persistent search cache.
  Future<void> saveRecentPlace(PlaceSuggestion place, {String? query, String? category}) async {
    try {
      await _db.saveRecentPlace(place, query: query, category: category);
    } catch (e) {
      debugPrint('LocalStore: SQLite saveRecentPlace error: $e');
    }
  }

  /// Retrieves recent places from the persistent search cache.
  Future<List<PlaceSuggestion>> getRecentPlaces({int limit = 10}) async {
    try {
      return await _db.getRecentPlaces(limit: limit);
    } catch (e) {
      debugPrint('LocalStore: SQLite getRecentPlaces error: $e');
      return [];
    }
  }

  /// Searches previously cached places matching [query] offline.
  Future<List<PlaceSuggestion>> searchCachedPlaces(String query, {int limit = 10}) async {
    try {
      return await _db.searchCachedPlaces(query, limit: limit);
    } catch (e) {
      debugPrint('LocalStore: SQLite searchCachedPlaces error: $e');
      return [];
    }
  }

  Future<void> clearRecentPlaces() async {
    try {
      await _db.clearRecentPlaces();
    } catch (_) {}
  }

  // ===========================================================================
  // DOMAIN STORAGE: PENDING TRANSACTIONS (SYNC OUTBOX)
  // ===========================================================================

  Future<void> savePendingOperations(List<PendingOperation> ops, {bool isDeadLetter = false}) async {
    try {
      final key = isDeadLetter ? deadLetterKey : outboxKey;
      await _db.clearPendingTransactions(deadLetterOnly: isDeadLetter);
      await _db.savePendingTransactions(ops, isDeadLetter: isDeadLetter);
      await writeJson(key, ops.map((o) => o.toJson()).toList());
    } catch (e) {
      debugPrint('LocalStore: SQLite savePendingOperations error: $e');
    }
  }

  Future<List<PendingOperation>> getPendingOperations({bool deadLetterOnly = false}) async {
    try {
      final fromDb = await _db.getPendingTransactions(deadLetterOnly: deadLetterOnly);
      if (fromDb.isNotEmpty) return fromDb;
    } catch (e) {
      debugPrint('LocalStore: SQLite getPendingOperations error: $e');
    }

    final key = deadLetterOnly ? deadLetterKey : outboxKey;
    final raw = await readJson(key);
    if (raw is List) {
      return raw
          .map((item) => item is Map ? PendingOperation.tryFromJson(Map<String, dynamic>.from(item)) : null)
          .whereType<PendingOperation>()
          .toList();
    }
    return [];
  }

  Future<void> deletePendingOperation(String id) async {
    try {
      await _db.deletePendingTransaction(id);
    } catch (_) {}
  }

  // ===========================================================================
  // GENERIC KEY-VALUE PERSISTENCE (SQLite + SharedPreferences Mirror)
  // ===========================================================================

  /// Reads a JSON object by key, querying SQLite KV store with SharedPreferences fallback.
  Future<Object?> readJson(String key) async {
    try {
      final fromDb = await _db.getKvString(key);
      if (fromDb != null && fromDb.isNotEmpty) {
        return await JsonIsolate.decode(fromDb);
      }
    } catch (e) {
      debugPrint('LocalStore: SQLite readJson for $key fallback: $e');
    }

    try {
      final raw = (await _prefs).getString(key);
      if (raw == null || raw.isEmpty) return null;
      return await JsonIsolate.decode(raw);
    } catch (e) {
      debugPrint('LocalStore: SharedPreferences cannot read $key: $e');
      return null;
    }
  }

  /// Writes a JSON object by key, updating both SQLite KV table and SharedPreferences.
  Future<void> writeJson(String key, Object? value) async {
    final encoded = await JsonIsolate.encode(value);
    try {
      await _db.setKvString(key, encoded);
    } catch (e) {
      debugPrint('LocalStore: SQLite setKvString for $key error: $e');
    }

    try {
      await (await _prefs).setString(key, encoded);
    } catch (e) {
      debugPrint('LocalStore: SharedPreferences setString for $key error: $e');
    }
  }

  Future<int?> readInt(String key) async {
    try {
      final val = await _db.getKvString(key);
      if (val != null) return int.tryParse(val);
    } catch (_) {}
    return (await _prefs).getInt(key);
  }

  Future<void> writeInt(String key, int value) async {
    try {
      await _db.setKvString(key, value.toString());
    } catch (_) {}
    await (await _prefs).setInt(key, value);
  }

  Future<void> remove(String key) async {
    try {
      await _db.removeKvKey(key);
    } catch (_) {}
    await (await _prefs).remove(key);
  }
}
