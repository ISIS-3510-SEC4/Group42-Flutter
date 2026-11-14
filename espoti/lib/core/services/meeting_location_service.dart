import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../models/participant_location.dart';
import 'auth_service.dart';
import 'user_service.dart';

/// Stores and retrieves participants' locations in Cloud Firestore.
///
/// Structure: `meetings/{meetingId}/locations/{userId}` where `{userId}` is the
/// Firebase Auth uid, so each user has exactly one document per meeting that
/// is overwritten with their latest position:
///   { meetingId, userId, name, latitude, longitude, timestamp (server) }
///
/// The existing meeting map consumes [locationsFor].
class MeetingLocationService {
  static final MeetingLocationService _instance =
      MeetingLocationService._internal();
  factory MeetingLocationService() => _instance;
  MeetingLocationService._internal();

  final Map<String, _LocationsNotifier> _notifiers = {};

  CollectionReference<Map<String, dynamic>> _locations(String meetingId) =>
      FirebaseFirestore.instance
          .collection('meetings')
          .doc(meetingId)
          .collection('locations');

  // Escritura: el id del documento es el uid. Las reglas exigen auth.uid ==
  // uid, userId == uid, ser participante y estar en la ventana de la reunión.
  // moving guarda el estado del acelerómetro en ese momento.
  /// Writes the signed-in user's latest location (asynchronous).
  /// Throws if the user is not authenticated or the write fails.
  Future<void> updateMyLocation(
    String meetingId, {
    required double latitude,
    required double longitude,
    bool moving = false,
  }) async {
    // Authenticate Actors: the document id is the verified Firebase uid.
    final user = AuthService().currentUser;
    if (user == null) {
      throw StateError('Usuario no autenticado.');
    }

    await _locations(meetingId).doc(user.uid).set({
      'meetingId': meetingId,
      'userId': user.uid,
      'name': UserService().currentUser.name,
      'latitude': latitude,
      'longitude': longitude,
      // Estado del acelerómetro al enviar la posición: los demás
      // participantes lo usan para mostrar "is moving" cerca de la hora.
      'moving': moving,
      'timestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Acceso a los datos: listener en tiempo real (snapshots) activo solo
  // mientras alguien escucha. Lo consumen LocationSyncStatusLine (cuántos
  // tienen ubicación) y OnTheWayNotice (aviso "en camino"). No hay un mapa que
  // dibuje estas posiciones: el detalle de la reunión muestra un ícono
  // estático.
  /// Live map of userId -> latest location for [meetingId], synchronized from
  /// Firestore. The Firestore listener starts with the first listener of the
  /// returned notifier and stops when the last one is removed.
  ValueListenable<Map<String, ParticipantLocation>> locationsFor(
          String meetingId) =>
      _notifiers.putIfAbsent(
        meetingId,
        () => _LocationsNotifier(_locations(meetingId)),
      );
}

/// ValueNotifier fed by a Firestore snapshot listener that is only active
/// while someone is listening.
class _LocationsNotifier
    extends ValueNotifier<Map<String, ParticipantLocation>> {
  _LocationsNotifier(this._query) : super(const {});

  final Query<Map<String, dynamic>> _query;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    _subscribe();
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners) {
      _subscription?.cancel();
      _subscription = null;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    super.dispose();
  }

  void _subscribe() {
    if (_subscription != null) return;
    try {
      _subscription = _query.snapshots().listen(
        _onSnapshot,
        onError: (Object e) =>
            // e.g. permission-denied from Firestore rules, or offline.
            debugPrint('Locations listener error: $e'),
      );
    } catch (e) {
      debugPrint('Locations listener failed to start: $e');
    }
  }

  void _onSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final result = <String, ParticipantLocation>{};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final lat = data['latitude'];
      final lng = data['longitude'];
      if (lat is! num || lng is! num) continue;
      final timestamp = data['timestamp'];
      result[doc.id] = ParticipantLocation(
        userId: (data['userId'] as String?) ?? doc.id,
        name: (data['name'] as String?) ?? '',
        latitude: lat.toDouble(),
        longitude: lng.toDouble(),
        // null while the server timestamp of a local write is still pending.
        updatedAt: timestamp is Timestamp ? timestamp.toDate() : DateTime.now(),
        moving: data['moving'] == true,
      );
    }
    value = result;
  }
}
