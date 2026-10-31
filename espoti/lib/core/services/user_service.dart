import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user.dart';
import '../offline/connectivity_service.dart';
import '../offline/local_store.dart';
import '../offline/pending_operation.dart';
import '../offline/sync_service.dart';
import '../offline/sync_queue.dart';

/// Profile of the signed-in user.
///
/// Source of truth: Firestore `users/{firebaseUid}` (one document per Firebase
/// uid, so it can never be duplicated). A copy is kept locally per uid so the
/// profile is available offline and after restarting the app. Writes go
/// through the sync outbox, so they also work offline.
class UserService {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  static const String collection = 'users';

  /// Re-read the profile from Firestore at most every 30 minutes.
  static const Duration remoteTtl = Duration(minutes: 30);

  final ValueNotifier<AppUser> userNotifier = ValueNotifier<AppUser>(mockUser);

  AppUser get currentUser => userNotifier.value;

  String? _uid;

  /// Loads the profile of the current Firebase user: local copy first (fast,
  /// offline), then Firestore. Ensures `users/{uid}` exists.
  /// Call it at app start and right after every sign-in.
  ///
  /// With [awaitRemote] false (app start) the Firestore part runs in the
  /// background so a slow network never delays the first frame.
  Future<void> init({bool awaitRemote = true}) async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      _uid = null;
      userNotifier.value = mockUser;
      return;
    }
    final uid = firebaseUser.uid;
    _uid = uid;

    try {
      final local = await _readLocal(uid);
      userNotifier.value = local ?? _fromAuth(firebaseUser);
      if (local == null) await _writeLocal(uid, userNotifier.value);

      final remote = _syncProfile(firebaseUser, force: local == null);
      if (awaitRemote) {
        await remote;
      } else {
        unawaited(remote);
      }
    } catch (e) {
      debugPrint('Error initializing UserService: $e');
    }
  }

  Future<void> _syncProfile(User firebaseUser, {required bool force}) async {
    final uid = firebaseUser.uid;
    try {
      await _refreshFromFirestore(uid, force: force);

      // Creates the document if missing (full profile) or only refreshes the
      // auth fields if it exists, so remote edits are never overwritten.
      await SyncService.instance.enqueue(PendingOperation.create(
        kind: PendingWriteKind.upsert,
        collection: collection,
        docId: uid,
        ownerUid: uid,
        data: _authFields(firebaseUser),
        dataIfMissing: _profileFields(userNotifier.value),
      ));
    } catch (e) {
      debugPrint('Error syncing user profile: $e');
    }
  }

  /// Updates the profile locally and queues it for Firestore.
  Future<void> saveUser(AppUser user) async {
    userNotifier.value = user;
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final uid = firebaseUser?.uid ?? _uid;
    if (uid == null) return;
    _uid = uid;

    try {
      await _writeLocal(uid, user);
      await SyncQueue.instance.enqueueProfileUpdate(
        uid: uid,
        data: {
          ..._profileFields(user),
          'firebaseUid': uid,
          if (firebaseUser != null) ..._authFields(firebaseUser),
        },
      );
    } catch (e) {
      debugPrint('Error saving user profile: $e');
    }

    // Keep Firebase Auth's display name/photo in line. Not awaited: it needs
    // network and must not block the UI when offline.
    if (firebaseUser != null) {
      unawaited(_updateAuthProfile(firebaseUser, user));
    }
  }

  /// Resets the profile on logout. Pending changes stay in the outbox and are
  /// sent the next time this user signs in.
  Future<void> clearUser() async {
    final uid = _uid;
    _uid = null;
    try {
      if (uid != null) {
        await LocalStore.instance.clearUserProfile(uid);
      }
    } catch (e) {
      debugPrint('Error clearing user profile: $e');
    }
    userNotifier.value = mockUser;
  }

  // ---------------------------------------------------------------------------

  Future<void> _refreshFromFirestore(String uid, {required bool force}) async {
    final fetchedAt =
        await LocalStore.instance.getUserFetchedAt(uid);
    final fresh = fetchedAt != null &&
        DateTime.now().millisecondsSinceEpoch - fetchedAt <
            remoteTtl.inMilliseconds;
    if (fresh && !force) return; // cache hit: no Firestore read

    if (!await ConnectivityService.instance.check()) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection(collection)
          .doc(uid)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 6));
      final data = doc.data();
      if (data != null && !SyncService.instance.hasPending(collection, uid)) {
        final remote = AppUser.fromJson(data);
        if (_uid == uid) userNotifier.value = remote;
        await _writeLocal(uid, remote);
      }
      await LocalStore.instance.saveUserFetchedAt(uid, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('Profile not refreshed from Firestore: $e');
    }
  }

  Future<AppUser?> _readLocal(String uid) async {
    return LocalStore.instance.getUserProfile(uid);
  }

  Future<void> _writeLocal(String uid, AppUser user) =>
      LocalStore.instance.saveUserProfile(user, uid);

  Future<void> _updateAuthProfile(User firebaseUser, AppUser user) async {
    try {
      if (user.name.isNotEmpty && firebaseUser.displayName != user.name) {
        await firebaseUser.updateDisplayName(user.name);
      }
      if (user.avatarUrl.isNotEmpty && firebaseUser.photoURL != user.avatarUrl) {
        await firebaseUser.updatePhotoURL(user.avatarUrl);
      }
    } catch (e) {
      debugPrint('Firebase Auth profile not updated: $e');
    }
  }

  static Map<String, dynamic> _authFields(User firebaseUser) => {
        'firebaseUid': firebaseUser.uid,
        'email': firebaseUser.email ?? '',
        'authProviders':
            firebaseUser.providerData.map((p) => p.providerId).toList(),
        'lastLoginAt': PendingOperation.timestamp(DateTime.now()),
      };

  static Map<String, dynamic> _profileFields(AppUser user) => user.toJson();

  static AppUser _fromAuth(User firebaseUser) {
    final displayName = firebaseUser.displayName ?? '';
    final parts = displayName.trim().split(RegExp(r'\s+'));
    final firstName = parts.isNotEmpty ? parts.first : '';
    final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    return AppUser(
      firstName: firstName,
      lastName: lastName,
      name: displayName.isNotEmpty
          ? displayName
          : (firebaseUser.email?.split('@').first ?? 'User'),
      code: 'ESP${(firebaseUser.uid.hashCode % 9000 + 1000).abs()}',
      location: 'Bogotá D.C.',
      preferences: const ['Walk', 'Eat'],
      maxRadiusKm: 10,
      avatarUrl: firebaseUser.photoURL ??
          'https://images.pexels.com/photos/39987037/pexels-photo-39987037.jpeg',
      email: firebaseUser.email ?? '',
      description: '',
      phone: firebaseUser.phoneNumber ?? '',
    );
  }
}
