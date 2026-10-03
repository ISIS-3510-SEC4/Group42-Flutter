import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'activity_context_service.dart';
import 'meeting_location_service.dart';

/// State of the location sharing.
enum LocationSyncStatus {
  idle, // not inside an active meeting
  sharing, // moving: periodic GPS updates
  paused, // stationary: updates stopped to save battery/network
  sensorUnavailable, // no accelerometer: slow heartbeat fallback
  permissionDenied,
  permissionDeniedForever,
  serviceDisabled, // GPS turned off
  error,
}

/// Accelerometer -> GPS -> Firestore.
///
/// Observes [ActivityContextService] (movement only). While the user is in an
/// active meeting:
///  - moving       -> GPS is read every [movingInterval] and written to
///                    Firestore through [MeetingLocationService];
///  - stationary   -> one final update (if they had been moving), then stop;
///  - moving again -> updates resume immediately.
/// Near-identical positions are not re-sent.
class LocationSharingService {
  static final LocationSharingService _instance =
      LocationSharingService._internal();
  factory LocationSharingService() => _instance;
  LocationSharingService._internal();

  static const Duration movingInterval = Duration(seconds: 15);
  static const Duration fallbackInterval = Duration(minutes: 2);
  static const Duration _minGap = Duration(seconds: 5);
  static const double _minDistanceMeters = 15; // avoid sending same spot repeatedly
  static const Duration _gpsTimeout = Duration(seconds: 10);
  static const Duration _writeTimeout = Duration(seconds: 10);

  final ValueNotifier<LocationSyncStatus> statusNotifier =
      ValueNotifier<LocationSyncStatus>(LocationSyncStatus.idle);

  final ActivityContextService _activity = ActivityContextService();

  String? _meetingId;
  Timer? _timer;
  bool _updating = false;
  bool _permissionAsked = false;
  MotionState _previousState = MotionState.unknown;
  Position? _lastSent;
  DateTime? _lastSentAt;

  /// Call when the user enters an active meeting. Safe to call repeatedly.
  Future<void> startForMeeting(String meetingId) async {
    if (_meetingId == meetingId) return;
    stopForMeeting();
    _meetingId = meetingId;
    statusNotifier.value = LocationSyncStatus.paused;
    _activity.stateNotifier.addListener(_onMotionChanged);
    _activity.start();
    // Share the starting position once so others can see the user right away.
    await _updateLocation(force: true);
  }

  /// Call when the user leaves the meeting: stops sensor, GPS and timers.
  void stopForMeeting() {
    _activity.stateNotifier.removeListener(_onMotionChanged);
    _activity.stop();
    _timer?.cancel();
    _timer = null;
    _meetingId = null;
    _lastSent = null;
    _lastSentAt = null;
    _permissionAsked = false;
    _previousState = MotionState.unknown;
    statusNotifier.value = LocationSyncStatus.idle;
  }

  void _onMotionChanged() {
    if (_meetingId == null) return;
    final state = _activity.state;
    final previous = _previousState;
    _previousState = state;

    switch (state) {
      case MotionState.moving:
        debugPrint('LocationSharing: MOVING - updating location');
        _restartTimer(movingInterval);
        _updateLocation();
      case MotionState.stationary:
        debugPrint('LocationSharing: STATIONARY - location updates paused');
        _timer?.cancel();
        _timer = null;
        if (previous == MotionState.moving) _updateLocation(force: true);
      case MotionState.unavailable:
        // Cannot tell movement: slow heartbeat instead of sharing nothing.
        statusNotifier.value = LocationSyncStatus.sensorUnavailable;
        _restartTimer(fallbackInterval);
      case MotionState.unknown:
        break;
    }
  }

  void _restartTimer(Duration interval) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => _updateLocation());
  }

  /// Gets the GPS position and writes it to Firestore. [force] skips the
  /// "same position" check (the minimum gap still applies).
  Future<void> _updateLocation({bool force = false}) async {
    final meetingId = _meetingId;
    if (meetingId == null || _updating) return;
    if (_lastSentAt != null &&
        DateTime.now().difference(_lastSentAt!) < _minGap) {
      return;
    }

    _updating = true;
    try {
      if (!await _ensureLocationAccess()) return;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: _gpsTimeout,
        ),
      );
      if (_meetingId != meetingId) return; // left the meeting meanwhile

      final last = _lastSent;
      if (!force && last != null) {
        final moved = Geolocator.distanceBetween(
          last.latitude,
          last.longitude,
          position.latitude,
          position.longitude,
        );
        if (moved < _minDistanceMeters) return; // do not resend same spot
      }

      await MeetingLocationService()
          .updateMyLocation(
            meetingId,
            latitude: position.latitude,
            longitude: position.longitude,
          )
          .timeout(_writeTimeout);

      debugPrint(
        'Location updated: ${position.latitude}, ${position.longitude}',
      );

      _lastSent = position;
      _lastSentAt = DateTime.now();
      _setStatus(_statusForMotion());
    } on TimeoutException {
      debugPrint('GPS or Firestore write timeout');
      _setStatus(LocationSyncStatus.error);
    } on LocationServiceDisabledException {
      _setStatus(LocationSyncStatus.serviceDisabled);
    } on PermissionDeniedException {
      _setStatus(LocationSyncStatus.permissionDenied);
    } catch (e) {
      // Firestore errors (rules, offline, not signed in) and anything else.
      debugPrint('Location update failed: $e');
      _setStatus(LocationSyncStatus.error);
    } finally {
      _updating = false;
    }
  }

  LocationSyncStatus _statusForMotion() => switch (_activity.state) {
        MotionState.unavailable => LocationSyncStatus.sensorUnavailable,
        MotionState.moving => LocationSyncStatus.sharing,
        _ => LocationSyncStatus.paused,
      };

  void _setStatus(LocationSyncStatus status) {
    if (_meetingId != null) statusNotifier.value = status;
  }

  /// Checks GPS service + permission (asks once per meeting visit).
  Future<bool> _ensureLocationAccess() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      _setStatus(LocationSyncStatus.serviceDisabled);
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && !_permissionAsked) {
      _permissionAsked = true;
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      _setStatus(LocationSyncStatus.permissionDeniedForever);
      return false;
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.unableToDetermine) {
      _setStatus(LocationSyncStatus.permissionDenied);
      return false;
    }
    return true;
  }
}
