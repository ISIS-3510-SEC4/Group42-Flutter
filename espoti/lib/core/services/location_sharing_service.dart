import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../../models/meeting_record.dart';
import 'activity_context_service.dart';
import 'meeting_location_service.dart';
import '../offline/local_store.dart';

/// State of the location sharing.
enum LocationSyncStatus {
  idle, // not inside an active meeting
  detecting, // accelerometer still deciding (MotionState.unknown)
  sharing, // moving: periodic GPS updates
  paused, // stationary: updates stopped to save battery/network
  sensorUnavailable, // no accelerometer: slow heartbeat fallback
  permissionDenied,
  permissionDeniedForever,
  serviceDisabled, // GPS turned off
  outsideWindow, // meeting not in its location window (or canceled)
  error,
}

/// Accelerometer -> GPS -> Firestore.
///
/// Only for eligible meetings: not canceled and inside the location window
/// around the scheduled time ([MeetingRecord.isInLocationWindow]); sharing
/// stops by itself when the window ends. The screen must also check that the
/// user is a participant (Firestore rules enforce both conditions too).
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

  static const int movingIntervalSeconds = 15;
  static const Duration movingInterval = Duration(seconds: movingIntervalSeconds);
  static const Duration fallbackInterval = Duration(minutes: 2);
  static const Duration _minGap = Duration(seconds: 5);
  /// Distancia mínima (en metros) entre dos posiciones enviadas: si el GPS
  /// marca que te moviste menos de esto, no se vuelve a escribir en Firestore.
  /// Se fijó en 1 m para que en la sustentación se vea el envío con solo
  /// caminar unos pasos. Ojo: el GPS de un teléfono suele tener un error de
  /// 3 a 10 m, así que con 1 m también pueden enviarse cambios por ruido.
  static const double minDistanceMeters = 1;

  /// Identifica a este servicio como "dueño" del acelerómetro.
  static const Object _sensorOwner = 'location_sharing';
  static const Duration _gpsTimeout = Duration(seconds: 10);
  static const Duration _writeTimeout = Duration(seconds: 10);

  final ValueNotifier<LocationSyncStatus> statusNotifier =
      ValueNotifier<LocationSyncStatus>(LocationSyncStatus.idle);

  final ActivityContextService _activity = ActivityContextService();

  String? _meetingId;
  MeetingRecord? _meeting;
  Timer? _timer;
  Timer? _windowEndTimer;
  bool _paused = false;
  bool _updating = false;
  bool _permissionAsked = false;
  MotionState _previousState = MotionState.unknown;
  Position? _lastSent;
  DateTime? _lastSentAt;

  /// Call when the user opens an eligible meeting. Safe to call repeatedly.
  /// Does nothing (status [LocationSyncStatus.outsideWindow]) when the
  /// meeting is canceled or outside its location window.
  Future<void> startForMeeting(MeetingRecord meeting) async {
    if (_meetingId == meeting.id) return;
    stopForMeeting();
    final now = DateTime.now();
    if (!meeting.isInLocationWindow(now)) {
      statusNotifier.value = LocationSyncStatus.outsideWindow;
      return;
    }
    _meetingId = meeting.id;
    _meeting = meeting;
    final endsAt = meeting.scheduledAt!.add(MeetingRecord.locationWindowAfter);
    _windowEndTimer = Timer(endsAt.difference(now), _onWindowEnded);
    // Motion is unknown until the accelerometer has enough samples.
    statusNotifier.value = LocationSyncStatus.detecting;
    _activity.stateNotifier.addListener(_onMotionChanged);
    _activity.start(owner: _sensorOwner);
    // Share the starting position once so others can see the user right away.
    await _updateLocation(force: true);
  }

  /// App went to background: stop sensor and GPS (foreground-only feature).
  void pause() {
    if (_meetingId == null || _paused) return;
    _paused = true;
    _activity.stateNotifier.removeListener(_onMotionChanged);
    _activity.stop(owner: _sensorOwner);
    _timer?.cancel();
    _timer = null;
    _previousState = MotionState.unknown;
  }

  /// App back in foreground: resume if the meeting is still eligible.
  void resume() {
    if (_meetingId == null || !_paused) return;
    _paused = false;
    if (!_isEligibleNow()) {
      _onWindowEnded();
      return;
    }
    statusNotifier.value = LocationSyncStatus.detecting;
    _activity.stateNotifier.addListener(_onMotionChanged);
    _activity.start(owner: _sensorOwner);
    _updateLocation(force: true);
  }

  /// Sign-out: stop sharing and forget the last position stored on the device.
  Future<void> clearOnSignOut() async {
    stopForMeeting();
    await LocalStore.instance.clearLastLocation();
  }

  bool _isEligibleNow() =>
      _meeting?.isInLocationWindow(DateTime.now()) ?? false;

  void _onWindowEnded() {
    if (_meetingId == null) return;
    debugPrint('LocationSharing: meeting location window ended');
    stopForMeeting();
    statusNotifier.value = LocationSyncStatus.outsideWindow;
  }

  /// Call when the user leaves the meeting: stops sensor, GPS and timers.
  void stopForMeeting() {
    _activity.stateNotifier.removeListener(_onMotionChanged);
    _activity.stop(owner: _sensorOwner);
    _timer?.cancel();
    _timer = null;
    _windowEndTimer?.cancel();
    _windowEndTimer = null;
    _meetingId = null;
    _meeting = null;
    _paused = false;
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
        _showMotion(LocationSyncStatus.sharing);
        _restartTimer(movingInterval);
        // Al empezar a moverse se envía aunque no haya cambiado la posición,
        // para que los demás vean pronto el campo `moving` (aviso "en camino").
        _updateLocation(force: previous != MotionState.moving);
      case MotionState.stationary:
        debugPrint('LocationSharing: STATIONARY - location updates paused');
        _showMotion(LocationSyncStatus.paused);
        _timer?.cancel();
        _timer = null;
        if (previous == MotionState.moving) _updateLocation(force: true);
      case MotionState.unavailable:
        // Cannot tell movement: slow heartbeat instead of sharing nothing.
        statusNotifier.value = LocationSyncStatus.sensorUnavailable;
        _restartTimer(fallbackInterval);
      case MotionState.unknown:
        // Not "stationary": the sensor has not decided yet.
        _showMotion(LocationSyncStatus.detecting);
    }
  }

  /// Shows the real motion state, without hiding a GPS/permission problem.
  void _showMotion(LocationSyncStatus status) {
    const motionStatuses = {
      LocationSyncStatus.detecting,
      LocationSyncStatus.sharing,
      LocationSyncStatus.paused,
      LocationSyncStatus.sensorUnavailable,
    };
    if (motionStatuses.contains(statusNotifier.value)) _setStatus(status);
  }

  void _restartTimer(Duration interval) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => _updateLocation());
  }

  /// Gets the GPS position and writes it to Firestore. [force] skips the
  /// "same position" check (the minimum gap still applies).
  Future<void> _updateLocation({bool force = false}) async {
    final meetingId = _meetingId;
    if (meetingId == null || _updating || _paused) return;
    if (!_isEligibleNow()) {
      _onWindowEnded();
      return;
    }
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
        if (moved < minDistanceMeters) return; // do not resend same spot
      }

      await MeetingLocationService()
          .updateMyLocation(
            meetingId,
            latitude: position.latitude,
            longitude: position.longitude,
            moving: _activity.state == MotionState.moving,
          )
          .timeout(_writeTimeout);

      debugPrint(
        'Location updated: ${position.latitude}, ${position.longitude}',
      );
      unawaited(LocalStore.instance.saveLastLocation(position.latitude, position.longitude));

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
        MotionState.stationary => LocationSyncStatus.paused,
        MotionState.unknown => LocationSyncStatus.detecting,
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
