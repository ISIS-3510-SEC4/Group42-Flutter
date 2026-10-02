import 'package:flutter/material.dart';
import '../../app/routes.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_strings.dart';
import '../../core/widgets/bottom_navigation.dart';
import '../../core/widgets/espoti_logo.dart';
import '../../core/widgets/meeting_card.dart';
import '../../models/meeting.dart';

class MeetingsPage extends StatefulWidget {
  const MeetingsPage({super.key});

  @override
  State<MeetingsPage> createState() => _MeetingsPageState();
}

class _MeetingsPageState extends State<MeetingsPage> {
  MeetingStatus _selectedStatus = MeetingStatus.upcoming;

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
      case EspotiNavItem.friends:
        break; 
    }
  }

  @override
  Widget build(BuildContext context) {
    // All mock meetings are tagged as "upcoming"; the Previous/Canceled
    // tabs are visually interactive but simply show an empty state since
 
    final meetings = MockMeetings.meetingsList
        .where((meeting) => meeting.status == _selectedStatus)
        .toList();

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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  EspotiLogo(height: AppDimensions.logoSizeSmall),
                  Icon(Icons.menu, color: AppColors.primaryBrown),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.paddingM),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingL),
              child: _StatusTabs(
                selected: _selectedStatus,
                onSelected: (status) => setState(() => _selectedStatus = status),
              ),
            ),
            const SizedBox(height: AppDimensions.paddingM),
            Expanded(
              child: meetings.isEmpty
                  ? const Center(
                      child: Text(
                        'No meetings here yet',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingL),
                      itemCount: meetings.length,
                      separatorBuilder: (_, __) => const SizedBox(height: AppDimensions.paddingM),
                      itemBuilder: (context, index) {
                        final meeting = meetings[index];
                        return MeetingCard(
                          placeName: meeting.placeName,
                          line1: meeting.timeLabel,
                          line2: meeting.distanceLabel,
                          avatarUrls: meeting.avatarUrls,
                          rating: meeting.rating,
                          onDetail: () {},
                          onTakePhoto: () {},
                        );
                      },
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
}

class _StatusTabs extends StatelessWidget {
  final MeetingStatus selected;
  final ValueChanged<MeetingStatus> onSelected;

  const _StatusTabs({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildTab(MeetingStatus.upcoming, AppStrings.upcoming, filled: true),
        const SizedBox(width: AppDimensions.paddingM),
        _buildTab(MeetingStatus.previous, AppStrings.previous, filled: false),
        const SizedBox(width: AppDimensions.paddingM),
        _buildTab(MeetingStatus.canceled, AppStrings.canceled, filled: false),
      ],
    );
  }

  Widget _buildTab(MeetingStatus status, String label, {required bool filled}) {
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
