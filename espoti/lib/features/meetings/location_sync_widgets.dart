import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/location_sharing_service.dart';
import '../../core/services/meeting_location_service.dart';
import '../../models/participant_location.dart';

/// Keeps the user's location shared while [child] (an active meeting screen)
/// is visible: starts on enter, stops on leave.
class ActiveMeetingLocationSync extends StatefulWidget {
  final String meetingId;
  final Widget child;

  const ActiveMeetingLocationSync({
    super.key,
    required this.meetingId,
    required this.child,
  });

  @override
  State<ActiveMeetingLocationSync> createState() =>
      _ActiveMeetingLocationSyncState();
}

class _ActiveMeetingLocationSyncState extends State<ActiveMeetingLocationSync> {
  @override
  void initState() {
    super.initState();
    LocationSharingService().startForMeeting(widget.meetingId);
  }

  @override
  void dispose() {
    LocationSharingService().stopForMeeting();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// One-line status of the location sharing, fed by the same
/// [MeetingLocationService] data the map consumes.
class LocationSyncStatusLine extends StatelessWidget {
  final String meetingId;
  const LocationSyncStatusLine({super.key, required this.meetingId});

  static String _message(LocationSyncStatus status) => switch (status) {
        LocationSyncStatus.sharing => 'En movimiento: compartiendo tu ubicación.',
        LocationSyncStatus.paused =>
          'Quieto: ubicación en pausa para ahorrar batería.',
        LocationSyncStatus.sensorUnavailable =>
          'Sin acelerómetro: ubicación compartida cada pocos minutos.',
        LocationSyncStatus.permissionDenied =>
          'Permite el acceso a tu ubicación para compartirla.',
        LocationSyncStatus.permissionDeniedForever =>
          'Activa el permiso de ubicación en los ajustes del teléfono.',
        LocationSyncStatus.serviceDisabled =>
          'Activa el GPS para compartir tu ubicación.',
        LocationSyncStatus.error =>
          'No se pudo obtener tu ubicación. Reintentaremos.',
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
          final text = _message(status);
          if (text.isEmpty) return const SizedBox.shrink();
          return Text(
            '$text (${locations.length} con ubicación)',
            style:
                const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          );
        },
      ),
    );
  }
}
