import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/activity_context_service.dart';
import '../../core/services/location_sharing_service.dart';
import '../../core/services/meeting_location_service.dart';
import '../../models/meeting_record.dart';
import '../../models/participant_location.dart';
import '../motion/motion_sensor_page.dart';

/// Keeps the user's location shared while [child] (an eligible meeting
/// screen) is visible: starts on enter, pauses in background, stops on leave.
/// The caller decides eligibility (participant + location window); the
/// service re-checks the window and stops when it ends.
class ActiveMeetingLocationSync extends StatefulWidget {
  final MeetingRecord meeting;
  final Widget child;

  const ActiveMeetingLocationSync({
    super.key,
    required this.meeting,
    required this.child,
  });

  @override
  State<ActiveMeetingLocationSync> createState() =>
      _ActiveMeetingLocationSyncState();
}

class _ActiveMeetingLocationSyncState extends State<ActiveMeetingLocationSync>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    LocationSharingService().startForMeeting(widget.meeting);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        LocationSharingService().resume();
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        LocationSharingService().pause();
      case AppLifecycleState.inactive:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    LocationSharingService().stopForMeeting();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Real accelerometer state, as detected by [ActivityContextService].
/// `unknown` is shown as "detecting", never as stationary.
class MotionStatusIndicator extends StatelessWidget {
  const MotionStatusIndicator({super.key});

  static (IconData, String) describe(MotionState state) => switch (state) {
        MotionState.unknown => (Icons.sensors, 'Detecting movement…'),
        MotionState.moving => (Icons.directions_walk, 'Moving'),
        MotionState.stationary => (Icons.accessibility_new, 'Still'),
        MotionState.unavailable =>
          (Icons.sensors_off, 'Accelerometer not available'),
      };

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MotionState>(
      valueListenable: ActivityContextService().stateNotifier,
      builder: (_, state, __) {
        final (icon, label) = describe(state);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.primaryBrown),
            const SizedBox(width: 4),
            Text('Accelerometer: $label',
                style: const TextStyle(fontSize: 12, color: AppColors.text)),
          ],
        );
      },
    );
  }
}

/// Status of the location sharing (motion indicator + one line), fed by the
/// same [MeetingLocationService] data the map consumes.
class LocationSyncStatusLine extends StatelessWidget {
  final String meetingId;
  const LocationSyncStatusLine({super.key, required this.meetingId});

  static String message(LocationSyncStatus status) => switch (status) {
        LocationSyncStatus.detecting =>
          'Starting position shared; detecting whether you are moving.',
        LocationSyncStatus.sharing =>
          'Moving: sharing your location (every ${LocationSharingService.movingIntervalSeconds} s, if you moved at least ${LocationSharingService.minDistanceMeters.toStringAsFixed(0)} m).',
        LocationSyncStatus.paused =>
          'Still: location updates paused to save battery.',
        LocationSyncStatus.sensorUnavailable =>
          'No accelerometer: location is shared every few minutes.',
        LocationSyncStatus.permissionDenied =>
          'Allow location access to share your location.',
        LocationSyncStatus.permissionDeniedForever =>
          'Enable the location permission in the phone settings.',
        LocationSyncStatus.serviceDisabled =>
          'Turn on GPS to share your location.',
        LocationSyncStatus.outsideWindow =>
          'The meeting is outside its time window: your location is no longer shared.',
        LocationSyncStatus.error =>
          'Could not get your location. We will try again.',
        LocationSyncStatus.idle => '',
      };

  @override
  Widget build(BuildContext context) {
    final sync = LocationSharingService();
    return ValueListenableBuilder<LocationSyncStatus>(
      valueListenable: sync.statusNotifier,
      builder: (_, status, __) => ValueListenableBuilder<
          Map<String, ParticipantLocation>>(
        valueListenable: MeetingLocationService().locationsFor(meetingId),
        builder: (_, locations, __) {
          final text = message(status);
          if (text.isEmpty) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (status != LocationSyncStatus.outsideWindow)
                // Lectura en vivo del acelerómetro (estado + valores).
                const MotionLiveCard(compact: true),
              Text(
                '$text (${locations.length} with location)',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Aviso "en camino": cuando un participante se está moviendo y la reunión
/// está cerca (de 1 h antes a 15 min después de la hora, ver
/// [MeetingRecord.isNearMeetingTime]), se indica que probablemente ya va
/// hacia el lugar.
///
/// - Para el usuario actual se usa su acelerómetro en vivo.
/// - Para los demás se usa el campo `moving` de su última posición en
///   Firestore, solo si es reciente (menos de [_freshness]); una posición
///   vieja no dice nada de lo que hacen ahora.
/// Un temporizador revisa cada 30 s, porque la condición depende de la hora.
class OnTheWayNotice extends StatefulWidget {
  final MeetingRecord meeting;
  final String? currentUserId;

  const OnTheWayNotice({super.key, required this.meeting, this.currentUserId});

  @override
  State<OnTheWayNotice> createState() => _OnTheWayNoticeState();
}

class _OnTheWayNoticeState extends State<OnTheWayNotice> {
  static const Duration _freshness = Duration(minutes: 3);
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MotionState>(
      valueListenable: ActivityContextService().stateNotifier,
      builder: (_, myMotion, __) =>
          ValueListenableBuilder<Map<String, ParticipantLocation>>(
        valueListenable: MeetingLocationService().locationsFor(widget.meeting.id),
        builder: (_, locations, __) {
          final now = DateTime.now();
          if (!widget.meeting.isNearMeetingTime(now)) {
            return const SizedBox.shrink();
          }
          final messages = <String>[
            if (myMotion == MotionState.moving)
              'You are moving — you may already be on your way to the meeting place.',
            for (final p in locations.values)
              if (p.userId != widget.currentUserId &&
                  p.moving &&
                  now.difference(p.updatedAt) < _freshness)
                '${p.name.isEmpty ? 'A participant' : p.name} is moving — they may already be on their way to the meeting place.',
          ];
          if (messages.isEmpty) return const SizedBox.shrink();
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accent1,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.orange),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final m in messages)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.directions_walk,
                            size: 18, color: AppColors.primaryBrown),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(m,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.text)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
