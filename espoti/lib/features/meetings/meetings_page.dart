import 'package:flutter/material.dart';
import '../../app/routes.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_strings.dart';
import '../../core/services/meeting_repository.dart';
import '../../core/widgets/bottom_navigation.dart';
import '../../core/widgets/espoti_logo.dart';
import '../../core/widgets/espoti_top_bar.dart';
import '../../core/widgets/meeting_card.dart';
import '../../core/widgets/sync_status_banner.dart';
import '../../models/meeting.dart';
import '../../models/meeting_record.dart';

/// The user's meetings, read from Firestore through MeetingRepository
/// (cache first, works offline with the last saved data).
class MeetingsPage extends StatefulWidget {
  const MeetingsPage({super.key});

  @override
  State<MeetingsPage> createState() => _MeetingsPageState();
}

class _MeetingsPageState extends State<MeetingsPage> {
  MeetingStatus _selectedStatus = MeetingStatus.upcoming;
  final _repository = MeetingRepository.instance;

  List<MeetingRecord> _meetings = const [];
  bool _loading = true;
  bool _stale = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository.changes.addListener(_onLocalChange);
    _load();
  }

  @override
  void dispose() {
    _repository.changes.removeListener(_onLocalChange);
    super.dispose();
  }

  void _onLocalChange() => _load();

  Future<void> _load({bool force = false}) async {
    try {
      final result = await _repository.myMeetings(forceRefresh: force);
      if (!mounted) return;
      setState(() {
        _meetings = result.meetings;
        _stale = result.stale;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar tus reuniones.';
        _loading = false;
      });
    }
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
    final now = DateTime.now();
    final meetings =
        _meetings.where((m) => m.uiStatus(now) == _selectedStatus).toList();

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
                selected: _selectedStatus,
                onSelected: (status) => setState(() => _selectedStatus = status),
              ),
            ),
            if (_stale && !_loading)
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
                onRefresh: () => _load(force: true),
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
    if (_loading) return const Center(child: CircularProgressIndicator());

    final message = _error ??
        (meetings.isEmpty
            ? (_selectedStatus == MeetingStatus.upcoming
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
          if (_error != null)
            Center(
              child: TextButton(
                onPressed: () => _load(force: true),
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
        final pending = _repository.isPending(meeting.id);

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
