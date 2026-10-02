import 'package:flutter/material.dart';
import '../../app/routes.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_strings.dart';
import '../../core/widgets/bottom_navigation.dart';
import '../../core/widgets/espoti_logo.dart';
import '../../models/meeting.dart';
import '../../core/widgets/attendee_avatars.dart';

/// "Create a meeting" (2) — shows the attendees and the
/// recommendations of places to vote. Without backend, recommendations are mocked.
class VoteMeetingPage extends StatefulWidget {
  const VoteMeetingPage({super.key});

  @override
  State<VoteMeetingPage> createState() => _VoteMeetingPageState();
}

class _VoteMeetingPageState extends State<VoteMeetingPage> {
  int _selectedIndex = 0;

  void _handleNavTap(EspotiNavItem item) {
    switch (item) {
      case EspotiNavItem.home:
        Navigator.pushReplacementNamed(context, AppRoutes.home);
        break;
      case EspotiNavItem.meetings:
        Navigator.pushReplacementNamed(context, AppRoutes.meetings);
        break;
      case EspotiNavItem.profile:
        Navigator.pushReplacementNamed(context, AppRoutes.profile);
        break;
      case EspotiNavItem.createMeeting:
        break;
      case EspotiNavItem.friends:
        break; // TODO: Friends Screen, when it exists
    }
  }

  void _handleVote() {
    Navigator.pushNamed(context, AppRoutes.winningPlace);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.symmetric(horizontal: AppDimensions.paddingL),
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
              const SizedBox(height: AppDimensions.paddingL),
              const Text(AppStrings.youWillMeet, style: _sectionTitleStyle),
              const SizedBox(height: AppDimensions.paddingM),
              const AttendeeAvatars(),
              const SizedBox(height: AppDimensions.paddingL),
              const Text(AppStrings.ourRecommendations,
                  style: _sectionTitleStyle),
              const SizedBox(height: AppDimensions.paddingM),
              for (int i = 0; i < MockMeetings.recommendations.length; i++) ...[
                _RecommendationCard(
                  meeting: MockMeetings.recommendations[i],
                  selected: _selectedIndex == i,
                  onTap: () => setState(() => _selectedIndex = i),
                ),
                const SizedBox(height: AppDimensions.paddingM),
              ],
              const SizedBox(height: AppDimensions.paddingM),
              Center(
                child: SizedBox(
                  width: 160,
                  height: AppDimensions.buttonHeight,
                  child: ElevatedButton(
                    onPressed: _handleVote,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBrown,
                      foregroundColor: AppColors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusPill),
                      ),
                    ),
                    child: const Text(
                      AppStrings.vote,
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.paddingXL),
            ],
          ),
        ),
      ),
      bottomNavigationBar: EspotiBottomNavigation(
        currentItem: EspotiNavItem.createMeeting,
        onItemSelected: _handleNavTap,
      ),
    );
  }
}

const _sectionTitleStyle = TextStyle(
  fontWeight: FontWeight.w700,
  fontSize: 16,
  color: AppColors.text,
);

/// Recommendation card for a place to vote.
class _RecommendationCard extends StatelessWidget {
  final Meeting meeting;
  final bool selected;
  final VoidCallback onTap;

  const _RecommendationCard({
    required this.meeting,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          border: Border.all(
            color: selected ? AppColors.orange : const Color(0xFFD9D9D9),
            width: selected ? 2 : 1,
          ),
          boxShadow: const [
            BoxShadow(
                color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(AppDimensions.radiusM),
              ),
              child: Container(
                width: 80,
                height: 80,
                color: AppColors.orange50,
                child: const Icon(Icons.image_outlined,
                    color: AppColors.primaryBrown),
              ),
            ),
            const SizedBox(width: AppDimensions.paddingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    meeting.placeName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.paddingXS),
                  Row(
                    children: List.generate(
                      (meeting.rating ?? 0).round(),
                      (_) => const Icon(Icons.star,
                          color: AppColors.orange, size: 16),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.paddingXS),
                  Text(
                    meeting.distanceLabel,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.paddingS),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(
                    selected ? Icons.check_circle : Icons.check_circle_outline,
                    color:
                        selected ? AppColors.orange : AppColors.textSecondary,
                    size: 20,
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      // TODO: Open place details when the screen exists.
                    },
                    icon: const Icon(
                      Icons.remove_red_eye_outlined,
                      color: AppColors.primaryBrown,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
