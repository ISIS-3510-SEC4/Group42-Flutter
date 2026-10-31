import 'dart:async';
import 'package:flutter/foundation.dart';

import 'connectivity_service.dart';
import 'local_store.dart';
import 'pending_operation.dart';
import 'sync_service.dart';

/// SyncQueue (Sprint 3 - Feature 2 / EvC):
/// Manages pending offline transactions and coordinates automatic synchronization
/// with Cloud Firestore when network connectivity is reestablished.
class SyncQueue {
  SyncQueue._() {
    _init();
  }

  /// Singleton instance of SyncQueue
  static final SyncQueue instance = SyncQueue._();

  final SyncService _syncService = SyncService.instance;
  final ConnectivityService _connectivity = ConnectivityService.instance;
  final LocalStore _storage = LocalStore.instance;

  ValueNotifier<SyncStatus> get status => _syncService.status;
  Stream<PendingOperation> get synced => _syncService.synced;
  Stream<PendingOperation> get conflicts => _syncService.conflicts;

  bool _initialized = false;

  void _init() {
    if (_initialized) return;
    _initialized = true;
    _syncService.start();
  }

  /// Adds a new operation to the pending sync queue and persists it locally.
  Future<void> enqueue(PendingOperation operation) async {
    await _syncService.enqueue(operation);
  }

  /// Convenience method to enqueue a profile update when offline or online.
  Future<void> enqueueProfileUpdate({
    required String uid,
    required Map<String, dynamic> data,
  }) async {
    final op = PendingOperation.create(
      kind: PendingWriteKind.upsert,
      collection: 'users',
      docId: uid,
      ownerUid: uid,
      data: data,
      checkConflict: true,
    );
    await enqueue(op);
  }

  /// Convenience method to enqueue a meeting creation/update when offline.
  Future<void> enqueueMeetingUpsert({
    required String meetingId,
    required String organizerId,
    required Map<String, dynamic> data,
  }) async {
    final op = PendingOperation.create(
      kind: PendingWriteKind.upsert,
      collection: 'meetings',
      docId: meetingId,
      ownerUid: organizerId,
      data: data,
      checkConflict: true,
    );
    await enqueue(op);
  }

  /// Manually triggers processing of the pending synchronization queue.
  Future<void> processQueue() async {
    final isOnline = await _connectivity.check();
    if (!isOnline) {
      debugPrint('SyncQueue: cannot process queue, device is offline');
      return;
    }
    await _syncService.syncNow();
  }

  /// Returns all currently pending operations stored in the queue.
  Future<List<PendingOperation>> getPendingOperations() =>
      _storage.getPendingOperations(deadLetterOnly: false);

  /// Checks if a specific document has pending changes waiting to sync.
  bool hasPending(String collection, String docId) =>
      _syncService.hasPending(collection, docId);

  /// Total count of pending operations.
  int get pendingCount => _syncService.status.value.pending;

  /// Whether the app is currently in online mode.
  bool get isOnline => _connectivity.isOnline.value;
}
