import 'package:flutter/material.dart';
import '../../app/routes.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_strings.dart';
import '../../core/widgets/bottom_navigation.dart';
import '../../core/widgets/espoti_button.dart';
import '../../core/widgets/espoti_logo.dart';
import '../../core/widgets/meeting_card.dart';
import '../../core/widgets/section_title.dart';
import '../../models/meeting.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});


  void _handleNavTap(BuildContext context, EspotiNavItem item) {
    switch (item) {
      case EspotiNavItem.home:
        break; 
      case EspotiNavItem.meetings:
        Navigator.pushReplacementNamed(context, AppRoutes.meetings);
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppDimensions.paddingM),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  EspotiLogo(height: AppDimensions.logoSizeSmall),
                
                  Icon(Icons.menu, color: AppColors.primaryBrown),
                ],
              ),
              const SizedBox(height: AppDimensions.paddingM),
              Text(AppStrings.greeting, style: Theme.of(context).textTheme.headlineMedium),
              const Text(
                AppStrings.tagline,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
              ),
              const SizedBox(height: AppDimensions.paddingL),
             //We need to add this after 
              const EspotiButton(
                label: AppStrings.createMeeting,
                variant: EspotiButtonVariant.secondary,
                onPressed: null,
              ),
              const SizedBox(height: AppDimensions.paddingL),
              const SectionTitle(title: AppStrings.nextMeetings),
              const SizedBox(height: AppDimensions.paddingS),
              SizedBox(
                height: 160,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: MockMeetings.nextMeetings.length,
                  separatorBuilder: (_, __) => const SizedBox(width: AppDimensions.paddingM),
                  itemBuilder: (context, index) {
                    final meeting = MockMeetings.nextMeetings[index];
                    return SizedBox(
                      width: 170,
                      child: MeetingCard(
                        placeName: meeting.placeName,
                        line1: meeting.timeLabel,
                        line2: meeting.distanceLabel,
                        avatarUrls: meeting.avatarUrls,
                        extraParticipantsLabel: meeting.extraParticipantsLabel,
                        compact: true,
                        onDetail: () {
                          Navigator.pushNamed(context, AppRoutes.meetingDetail);
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppDimensions.paddingL),
              const _InviteCoffeeCard(),
              const SizedBox(height: AppDimensions.paddingL),
              const SectionTitle(
                title: AppStrings.meetingHistory,
                trailingLabel: AppStrings.previousEvents,
              ),
              const SizedBox(height: AppDimensions.paddingS),
              const _HistoryGrid(),
              const SizedBox(height: AppDimensions.paddingL),
            ],
          ),
        ),
      ),
      bottomNavigationBar: EspotiBottomNavigation(
        currentItem: EspotiNavItem.home,
        onItemSelected: (item) => _handleNavTap(context, item),
      ),
    );
  }
}

class _InviteCoffeeCard extends StatelessWidget {
  const _InviteCoffeeCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: AppColors.orange50,
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
      ),
      child: Row(
        children: [
          const Icon(Icons.coffee, color: AppColors.primaryBrown, size: 28),
          const SizedBox(width: AppDimensions.paddingM),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.inviteCoffee,
                  style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.text),
                ),
                SizedBox(height: 2),
                Text(
                  AppStrings.inviteCoffeeSubtitle,
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppDimensions.paddingS),
          ElevatedButton(
            // Decorative support action after we connect with a backend.
            onPressed: null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBrown,
              foregroundColor: AppColors.white,
              minimumSize: const Size(0, 36),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
              ),
            ),
            child: const Text(AppStrings.support, style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _HistoryGrid extends StatelessWidget {
  const _HistoryGrid();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: _HistoryTile(seed: 'history1')),
        SizedBox(width: AppDimensions.paddingM),
        Expanded(child: _HistoryTile(seed: 'history2')),
      ],
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final String seed;

  const _HistoryTile({required this.seed});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimensions.radiusM),
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          color: AppColors.orange50,
          child: Image.network(
            'https://picsum.photos/seed/$seed/300/300',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.image_outlined,
              color: AppColors.primaryBrown,
              size: 32,
            ),
          ),
        ),
      ),
    );
  }
}
