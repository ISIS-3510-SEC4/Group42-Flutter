import 'package:flutter/material.dart';
import '../../app/routes.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_strings.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/meeting_repository.dart';
import '../../core/services/meeting_voting_service.dart';
import '../../core/widgets/espoti_top_bar.dart';
import '../../core/widgets/espoti_button.dart';
import '../../core/widgets/sync_status_banner.dart';
import '../../models/meeting_record.dart';
import 'budget_recommendation_service.dart';
import 'location_sync_widgets.dart';

/// Detail of a saved meeting. Open with `arguments: {'meetingId': id}`.
class MeetingDetailPage extends StatefulWidget {
  const MeetingDetailPage({super.key});

  @override
  State<MeetingDetailPage> createState() => _MeetingDetailPageState();
}

class _MeetingDetailPageState extends State<MeetingDetailPage> {
  String? _meetingId;
  MeetingRecord? _meeting;
  bool _loading = true;
  bool _didReadArgs = false;

  @override
  void initState() {
    super.initState();
    MeetingRepository.instance.changes.addListener(_load);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didReadArgs) return;
    _didReadArgs = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    _meetingId = args is Map ? args['meetingId'] as String? : null;
    _load();
  }

  @override
  void dispose() {
    MeetingRepository.instance.changes.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final id = _meetingId;
    // Reuniones propias desde el repositorio; si no está (el usuario es
    // invitado), desde las invitaciones del servicio de votación.
    final meeting = id == null
        ? null
        : await MeetingRepository.instance.byId(id) ??
            await MeetingVotingService.instance.fetchMeeting(id);
    if (!mounted) return;
    setState(() {
      _meeting = meeting;
      _loading = false;
    });
  }

  Future<void> _edit() async {
    await Navigator.pushNamed(
      context,
      AppRoutes.createMeeting,
      arguments: {'meetingId': _meetingId},
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final meeting = _meeting;
    final scaffold = Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primaryBrown),
        title: const Text(
          AppStrings.detail,
          style: TextStyle(color: AppColors.primaryBrown),
        ),
        // Mismo menú hamburguesa que el resto de pantallas.
        actions: const [EspotiMenuButton()],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : meeting == null
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppDimensions.paddingL),
                    child: Text(
                      'This meeting is not available on this device. Check your connection and try again.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                )
              : _buildBody(meeting),
    );

    // Share location (depending on movement) only for eligible meetings:
    // the user is a participant and the meeting is inside its time window.
    if (meeting == null || !_sharesLocation(meeting)) return scaffold;
    return ActiveMeetingLocationSync(meeting: meeting, child: scaffold);
  }

  bool _isParticipant(MeetingRecord meeting) {
    final user = AuthService().currentUser;
    return user != null && meeting.isParticipant(user.uid, user.email);
  }

  bool _sharesLocation(MeetingRecord meeting) =>
      _isParticipant(meeting) && meeting.isInLocationWindow(DateTime.now());

  Widget _buildBody(MeetingRecord meeting) {
    final pending = MeetingRepository.instance.isPending(meeting.id);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SyncStatusBanner(),
          Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.accent1,
              borderRadius: BorderRadius.circular(AppDimensions.radiusL),
            ),
            child: const Icon(Icons.map, size: 64, color: AppColors.orange50),
          ),
          const SizedBox(height: AppDimensions.paddingS),
          if (_sharesLocation(meeting)) ...[
            LocationSyncStatusLine(meetingId: meeting.id),
            // "Se está moviendo, puede que ya vaya al lugar" cerca de la hora.
            OnTheWayNotice(
              meeting: meeting,
              currentUserId: AuthService().currentUser?.uid,
            ),
          ] else
            Text(
              meeting.status == MeetingRecord.canceled
                  ? 'Canceled meeting: location is not shared.'
                  : 'Your location is only shared from '
                      '${MeetingRecord.locationWindowBefore.inHours} h before to '
                      '${MeetingRecord.locationWindowAfter.inHours} h after the meeting time.',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          const SizedBox(height: AppDimensions.paddingM),
          Text(
            meeting.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
          if (meeting.placeCategory != null && meeting.placeCategory!.isNotEmpty)
            Text(meeting.placeCategory!,
                style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: AppDimensions.paddingM),
          _InfoRow(icon: Icons.event, text: meeting.whenLabel),
          _InfoRow(icon: Icons.local_activity_outlined, text: meeting.activity),
          if (meeting.transitMode != null)
            _InfoRow(icon: Icons.commute, text: meeting.transitMode!.label),
          if (meeting.budgetPerPerson != null)
            _InfoRow(
              icon: Icons.payments_outlined,
              text:
                  'Up to \$${BudgetRecommendationService.formatCop(meeting.budgetPerPerson!)} COP per person',
            ),
          if (pending)
            const _InfoRow(
                icon: Icons.cloud_upload_outlined,
                text: 'Saved on this device · pending sync'),
          const SizedBox(height: AppDimensions.paddingL),
          const Text(
            'They are also going:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: AppDimensions.paddingS),
          if (meeting.inviteeNames.isEmpty)
            const Text('No invitees yet.',
                style: TextStyle(color: AppColors.textSecondary))
          else if (meeting.invitees.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final invitee in meeting.invitees)
                  _InfoRow(
                    icon: Icons.mail_outline,
                    text: invitee.email.isEmpty
                        ? '${invitee.displayName} · invitation saved (not sent)'
                        : '${invitee.displayName} (${invitee.email}) · invitation saved (not sent)',
                  ),
              ],
            )
          else
            Wrap(
              spacing: AppDimensions.paddingS,
              runSpacing: AppDimensions.paddingS,
              children: [
                for (final name in meeting.inviteeNames)
                  Chip(
                    label: Text(name),
                    backgroundColor: AppColors.orange50,
                    side: BorderSide.none,
                  ),
              ],
            ),
          const SizedBox(height: AppDimensions.paddingL),
          if (meeting.isVotingOpen) ...[
            // Votación abierta: acceso directo a votar / ver el recuento.
            SizedBox(
              width: double.infinity,
              child: EspotiButton(
                label: 'Open voting',
                variant: EspotiButtonVariant.secondary,
                onPressed: () => Navigator.pushNamed(
                    context, AppRoutes.meetingVoting,
                    arguments: {'meetingId': meeting.id}),
              ),
            ),
            const SizedBox(height: AppDimensions.paddingM),
          ],
          // Solo el organizador puede editar (igual que en las reglas).
          if (meeting.status != MeetingRecord.canceled &&
              meeting.organizerId == AuthService().currentUser?.uid)
            SizedBox(
              width: double.infinity,
              child: EspotiButton(
                label: 'Edit meeting',
                variant: EspotiButtonVariant.primary,
                onPressed: _edit,
              ),
            ),
          const SizedBox(height: AppDimensions.paddingM),
          SizedBox(
            width: double.infinity,
            child: EspotiButton(
              label: AppStrings.back,
              variant: EspotiButtonVariant.secondary,
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primaryBrown),
          const SizedBox(width: AppDimensions.paddingS),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 15, color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}
