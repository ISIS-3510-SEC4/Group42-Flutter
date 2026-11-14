import 'package:flutter/material.dart';
import '../../app/routes.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_strings.dart';
import '../../core/widgets/bottom_navigation.dart';
import '../../core/widgets/espoti_top_bar.dart';
import '../../core/widgets/meeting_card.dart';
import '../../core/widgets/sync_status_banner.dart';
import '../../models/meeting.dart';
import '../../models/meeting_record.dart';
import 'meetings_view_model.dart';

/// The user's meetings, read from Firestore through MeetingRepository
/// (cache first, works offline with the last saved data).
class MeetingsPage extends StatefulWidget {
  const MeetingsPage({super.key});

  @override
  State<MeetingsPage> createState() => _MeetingsPageState();
}

class _MeetingsPageState extends State<MeetingsPage> {
  // MVVM: all screen state lives in the ViewModel; this State only owns it.
  // La pantalla crea el ViewModel, lo arranca y lo destruye en dispose.
  // Acciones del usuario que llegan al ViewModel: selectStatus (pestañas) y
  // refresh (pull-to-refresh y botón de reintento).
  final MeetingsViewModel _viewModel = MeetingsViewModel()..start();

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  void _handleNavTap(EspotiNavItem item) {
    switch (item) {
      case EspotiNavItem.home:
        Navigator.pushReplacementNamed(context, AppRoutes.home);
        break;
      case EspotiNavItem.meetings:
        break;
      case EspotiNavItem.profile:
        Navigator.pushReplacementNamed(context, AppRoutes.profile);
        break;
      case EspotiNavItem.createMeeting:
        Navigator.pushReplacementNamed(context, AppRoutes.createMeeting);
        break;
      case EspotiNavItem.friends:
        Navigator.pushReplacementNamed(context, AppRoutes.friends);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Observer (lado de la vista): ListenableBuilder escucha al ViewModel
    // (ChangeNotifier). Cada notifyListeners vuelve a ejecutar _buildScaffold,
    // que solo lee getters (loading, error, stale, visibleMeetings). La vista
    // nunca habla con Firestore ni con el repositorio.
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) => _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final meetings = _viewModel.visibleMeetings;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppDimensions.paddingL,
                AppDimensions.paddingM,
                AppDimensions.paddingL,
                0,
              ),
              child: EspotiTopBar(),
            ),
            const SizedBox(height: AppDimensions.paddingM),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppDimensions.paddingL),
              child: SyncStatusBanner(),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingL),
              child: _StatusTabs(
                selected: _viewModel.selectedStatus,
                onSelected: _viewModel.selectStatus,
              ),
            ),
            if (_viewModel.stale && !_viewModel.loading)
              const Padding(
                padding: EdgeInsets.fromLTRB(
                    AppDimensions.paddingL, AppDimensions.paddingS, AppDimensions.paddingL, 0),
                child: Text(
                  'Showing saved meetings; they may be outdated.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
            const SizedBox(height: AppDimensions.paddingM),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _viewModel.refresh,
                child: _buildList(meetings),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: EspotiBottomNavigation(
        currentItem: EspotiNavItem.meetings,
        onItemSelected: _handleNavTap,
      ),
    );
  }

  Widget _buildList(List<MeetingRecord> meetings) {
    if (_viewModel.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final error = _viewModel.error;
    final message = error ??
        (meetings.isEmpty
            ? (_viewModel.selectedStatus == MeetingStatus.upcoming
                ? 'No meetings here yet. Tap + to create one.'
                : 'No meetings here yet')
            : null);
    if (message != null) {
      // ListView so pull-to-refresh also works on the empty state.
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          Center(
            child: Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary)),
          ),
          if (error != null)
            Center(
              child: TextButton(
                onPressed: _viewModel.refresh,
                child: const Text('Retry'),
              ),
            ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingL),
      itemCount: meetings.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppDimensions.paddingM),
      itemBuilder: (context, index) {
        final meeting = meetings[index];
        final canceled = meeting.status == MeetingRecord.canceled;
        final pending = _viewModel.isPending(meeting.id);

        Widget? bottomWidget;
        if (canceled) {
          bottomWidget = Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              borderRadius: BorderRadius.circular(AppDimensions.radiusM),
            ),
            alignment: Alignment.center,
            child: const Text(
              'Canceled',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          );
        } else if (meeting.isVotingOpen) {
          // Votación abierta: se indica en la tarjeta (el detalle da acceso).
          bottomWidget = const Row(
            children: [
              Icon(Icons.how_to_vote_outlined, size: 16, color: AppColors.orange),
              SizedBox(width: 4),
              Text('Voting in progress',
                  style: TextStyle(fontSize: 12, color: AppColors.orange)),
            ],
          );
        } else if (_viewModel.isInvited(meeting)) {
          // Reunión de otra persona: el usuario es invitado (no la puede
          // editar, pero sí ver el detalle y compartir ubicación).
          bottomWidget = const Row(
            children: [
              Icon(Icons.mail_outline, size: 16, color: AppColors.textSecondary),
              SizedBox(width: 4),
              Text('You are invited',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          );
        } else if (pending) {
          bottomWidget = const Row(
            children: [
              Icon(Icons.cloud_upload_outlined, size: 16, color: AppColors.textSecondary),
              SizedBox(width: 4),
              Text('Pending sync',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          );
        }

        return MeetingCard(
          placeName: meeting.title,
          line1: meeting.whenLabel,
          line2: [
            if (meeting.placeName != null) meeting.activity,
            if (meeting.transitMode != null) meeting.transitMode!.label,
          ].join(' · '),
          extraParticipantsLabel: meeting.inviteeNames.isEmpty
              ? ''
              : meeting.inviteeNames.join(', '),
          onDetail: canceled
              ? null
              : () => Navigator.pushNamed(
                    context,
                    AppRoutes.meetingDetail,
                    arguments: {'meetingId': meeting.id},
                  ),
          bottomWidget: bottomWidget,
          backgroundColor: canceled ? Colors.grey.shade200 : null,
        );
      },
    );
  }
}

class _StatusTabs extends StatelessWidget {
  final MeetingStatus selected;
  final ValueChanged<MeetingStatus> onSelected;

  const _StatusTabs({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildTab(MeetingStatus.upcoming, AppStrings.upcoming),
        const SizedBox(width: AppDimensions.paddingM),
        _buildTab(MeetingStatus.previous, AppStrings.previous),
        const SizedBox(width: AppDimensions.paddingM),
        _buildTab(MeetingStatus.canceled, AppStrings.canceled),
      ],
    );
  }

  Widget _buildTab(MeetingStatus status, String label) {
    final isSelected = selected == status;
    return GestureDetector(
      onTap: () => onSelected(status),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryBrown : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.white : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
