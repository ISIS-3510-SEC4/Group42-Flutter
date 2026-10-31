import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../models/meeting_record.dart';
import '../cache/timed_cache.dart';
import '../offline/connectivity_service.dart';
import '../offline/local_store.dart';
import '../offline/pending_operation.dart';
import '../offline/sync_service.dart';

/// Result of loading the user's meetings.
class MeetingsResult {
  final List<MeetingRecord> meetings;

  /// Served from memory or the local snapshot (no Firestore read).
  final bool fromCache;

  /// The server could not be reached and the data may be outdated.
  final bool stale;

  const MeetingsResult(this.meetings, {this.fromCache = false, this.stale = false});
}

/// Meetings stored in Firestore `meetings/{meetingId}`, offline-first.
///
/// Reads: memory cache (TTL 5 min) -> local snapshot (TTL 5 min) -> Firestore.
/// If Firestore is unreachable the last snapshot is returned as stale.
/// Writes: applied to the local snapshot immediately and queued in the sync
/// outbox, so creating or editing a meeting works without connectivity.
class MeetingRepository {
  MeetingRepository._();
  static final MeetingRepository instance = MeetingRepository._();

  static const String collection = 'meetings';
  static const Duration ttl = Duration(minutes: 5);
  static const Duration _readTimeout = Duration(seconds: 10);

  final TimedCache<Map<String, MeetingRecord>> _cache = TimedCache(ttl: ttl);

  /// Increments whenever local meetings change (save, sync, conflict), so
  /// screens can reload from the cache.
  final ValueNotifier<int> changes = ValueNotifier<int>(0);

  StreamSubscription<PendingOperation>? _syncedSub;
  StreamSubscription<PendingOperation>? _conflictSub;
  StreamSubscription<User?>? _authSub;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  void _listenToSync() {
    // Logout: forget the in-memory copy of the previous user's meetings.
    _authSub ??= FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) clearMemory();
    });
    _syncedSub ??= SyncService.instance.synced.listen((op) {
      if (op.collection == collection) changes.value++;
    });
    // The server kept a newer version: drop our cache so it is re-read.
    _conflictSub ??= SyncService.instance.conflicts.listen((op) {
      if (op.collection != collection) return;
      _cache.invalidate();
      changes.value++;
    });
  }

  String newId() => const Uuid().v4();

  bool isPending(String meetingId) =>
      SyncService.instance.hasPending(collection, meetingId);

  Future<MeetingsResult> myMeetings({bool forceRefresh = false}) async {
    final uid = _uid;
    if (uid == null) return const MeetingsResult([]);
    _listenToSync();

    if (!forceRefresh) {
      final hit = _cache.get(uid);
      if (hit != null) return MeetingsResult(_sorted(hit), fromCache: true);
    }

    final snapshot = await _loadSnapshot(uid);
    final snapshotFresh = snapshot.fetchedAt != null &&
        DateTime.now().difference(snapshot.fetchedAt!) <= ttl;
    if (!forceRefresh && snapshotFresh) {
      _cache.put(uid, snapshot.records, storedAt: snapshot.fetchedAt);
      return MeetingsResult(_sorted(snapshot.records), fromCache: true);
    }

    final local = _cache.peek(uid) ?? snapshot.records;
    try {
      if (!await ConnectivityService.instance.check()) {
        throw const _Offline();
      }
      final remote = await _fetchRemote(uid).timeout(_readTimeout);
      final merged = _merge(remote, local);
      final now = DateTime.now();
      _cache.put(uid, merged, storedAt: now);
      await _saveSnapshot(uid, merged, now);
      return MeetingsResult(_sorted(merged));
    } catch (e) {
      if (e is! _Offline) debugPrint('Meetings fetch failed: $e');
      // Stale fallback: keep the old freshness so the next visit retries.
      _cache.put(uid, local,
          storedAt: snapshot.fetchedAt ?? DateTime.fromMillisecondsSinceEpoch(0));
      return MeetingsResult(_sorted(local), fromCache: true, stale: true);
    }
  }

  /// Meeting by id from local data (no network).
  Future<MeetingRecord?> byId(String id) async {
    final uid = _uid;
    if (uid == null) return null;
    final cached = _cache.peek(uid);
    if (cached != null && cached.containsKey(id)) return cached[id];
    return (await _loadSnapshot(uid)).records[id];
  }

  /// Creates or edits a meeting. Returns immediately after saving locally;
  /// Firestore is updated by the sync service (now or when back online).
  Future<MeetingRecord> save(MeetingRecord record) async {
    final uid = _uid;
    if (uid == null) throw StateError('Debes iniciar sesión para guardar reuniones.');
    if (record.organizerId != uid) {
      throw StateError('Solo el organizador puede editar esta reunión.');
    }
    _listenToSync();

    final saved = record.copyWith(
      updatedAtClient: DateTime.now().millisecondsSinceEpoch,
    );

    final snapshot = await _loadSnapshot(uid);
    final records = {...(_cache.peek(uid) ?? snapshot.records), saved.id: saved};
    if (_cache.peek(uid) == null) {
      _cache.put(uid, records,
          storedAt: snapshot.fetchedAt ?? DateTime.fromMillisecondsSinceEpoch(0));
    } else {
      _cache.update(uid, records);
    }
    await _saveSnapshot(uid, records, snapshot.fetchedAt);

    await SyncService.instance.enqueue(PendingOperation.create(
      kind: PendingWriteKind.upsert,
      collection: collection,
      docId: saved.id,
      ownerUid: uid,
      data: _toSyncData(saved),
      checkConflict: true,
    ));
    changes.value++;
    return saved;
  }

  /// Logout: forget the in-memory copy (the per-user snapshot stays on disk
  /// so pending changes of that user are not lost).
  void clearMemory() => _cache.clear();

  // ---------------------------------------------------------------------------

  Map<String, dynamic> _toSyncData(MeetingRecord r) {
    final json = r.toJson();
    json['scheduledAt'] =
        r.scheduledAt == null ? null : PendingOperation.timestamp(r.scheduledAt!);
    return json;
  }

  Future<Map<String, MeetingRecord>> _fetchRemote(String uid) async {
    // Single-field filter: no composite index is required. Sorting is local.
    final query = await FirebaseFirestore.instance
        .collection(collection)
        .where('organizerId', isEqualTo: uid)
        .get(const GetOptions(source: Source.server));
    final result = <String, MeetingRecord>{};
    for (final doc in query.docs) {
      final map = <String, dynamic>{
        ...doc.data().map((k, v) => MapEntry(k, v is Timestamp ? v.millisecondsSinceEpoch : v)),
        'id': doc.id,
      };
      final record = MeetingRecord.tryFromMap(map);
      if (record != null) result[record.id] = record;
    }
    return result;
  }

  /// Server data wins, except for meetings with changes still in the outbox.
  Map<String, MeetingRecord> _merge(
      Map<String, MeetingRecord> remote, Map<String, MeetingRecord> local) {
    final merged = {...remote};
    for (final entry in local.entries) {
      if (isPending(entry.key)) merged[entry.key] = entry.value;
    }
    return merged;
  }

  List<MeetingRecord> _sorted(Map<String, MeetingRecord> records) {
    final list = records.values.toList();
    list.sort((a, b) {
      final at = a.scheduledAt?.millisecondsSinceEpoch ?? a.createdAtClient;
      final bt = b.scheduledAt?.millisecondsSinceEpoch ?? b.createdAtClient;
      return bt.compareTo(at); // most recent first
    });
    return list;
  }

  Future<_Snapshot> _loadSnapshot(String uid) async {
    final raw = await LocalStore.instance.readJson(LocalStore.meetingsKey(uid));
    if (raw is! Map) return const _Snapshot(null, {});
    final fetchedAt = raw['fetchedAt'];
    final records = <String, MeetingRecord>{};
    final list = raw['records'];
    if (list is List) {
      for (final item in list) {
        if (item is Map) {
          final record = MeetingRecord.tryFromMap(Map<String, dynamic>.from(item));
          if (record != null) records[record.id] = record;
        }
      }
    }
    return _Snapshot(
      fetchedAt is int && fetchedAt > 0
          ? DateTime.fromMillisecondsSinceEpoch(fetchedAt)
          : null,
      records,
    );
  }

  Future<void> _saveSnapshot(
      String uid, Map<String, MeetingRecord> records, DateTime? fetchedAt) {
    return LocalStore.instance.writeJson(LocalStore.meetingsKey(uid), {
      'fetchedAt': fetchedAt?.millisecondsSinceEpoch ?? 0,
      'records': records.values.map((r) => r.toJson()).toList(),
    });
  }
}

class _Snapshot {
  final DateTime? fetchedAt;
  final Map<String, MeetingRecord> records;
  const _Snapshot(this.fetchedAt, this.records);
}

class _Offline implements Exception {
  const _Offline();
}
