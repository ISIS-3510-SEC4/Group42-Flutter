import 'package:flutter/material.dart';
import '../../app/routes.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_strings.dart';
import '../../core/widgets/attendee_avatars.dart';
import '../../core/widgets/bottom_navigation.dart';
import '../../core/widgets/espoti_logo.dart';
import '../../models/meeting.dart';

/// "Create a meeting" screen (3) — displays the winning place
/// from the vote and its reviews.
class WinningPlacePage extends StatelessWidget {
  const WinningPlacePage({super.key});

  void _handleNavTap(BuildContext context, EspotiNavItem item) {
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
        Navigator.pushReplacementNamed(context, AppRoutes.friends);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final routeArgs = ModalRoute.of(context)?.settings.arguments;
    final args = routeArgs is Map ? routeArgs : const <dynamic, dynamic>{};
    final placeName = args['placeName'] as String?;
    // The place chosen in step 2 (no invented data when it is missing).
    final winner = Meeting(
      placeName: placeName ?? 'No place selected',
      timeLabel: args['placeCategory'] as String? ?? '',
      distanceLabel: args['placeDetail'] as String? ?? '',
    );
    // There is no reviews source for OpenStreetMap places yet.
    const reviews = <MeetingReview>[];
    final day = (args['day'] as String?)?.trim() ?? '';
    final time = (args['time'] as String?)?.trim() ?? '';
    final transit = args['transitMode'] as String?;
    final choseOffline = args['offline'] == true;

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
              if (choseOffline) ...[
                const Text(
                  'Sin conexión: el lugar quedó guardado en tu teléfono y se compartirá con el grupo al reconectar.',
                  style: TextStyle(fontSize: 12, color: AppColors.orange),
                ),
                const SizedBox(height: AppDimensions.paddingM),
              ],
              const Text(AppStrings.youWillMeet, style: _sectionTitleStyle),
              const SizedBox(height: AppDimensions.paddingM),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const AttendeeAvatars(),
                  const SizedBox(width: AppDimensions.paddingS),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Date: ${day.isEmpty ? 'Not specified' : day}',
                            style: const TextStyle(
                                fontSize: 15, color: AppColors.text)),
                        Text('Hour: ${time.isEmpty ? 'Not specified' : time}',
                            style: const TextStyle(
                                fontSize: 15, color: AppColors.text)),
                        if (transit != null)
                          Text('Getting there: $transit',
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.paddingL),
              const Text(AppStrings.winningPlace, style: _sectionTitleStyle),
              const SizedBox(height: AppDimensions.paddingM),
              _PlaceCard(meeting: winner),
              const SizedBox(height: AppDimensions.paddingL),
              const Text(AppStrings.winningPlaceReviews,
                  style: _sectionTitleStyle),
              const SizedBox(height: AppDimensions.paddingM),
              if (reviews.isEmpty)
                const Text('No reviews yet for this place.',
                    style: TextStyle(color: AppColors.textSecondary)),
              for (final review in reviews) ...[
                _ReviewCard(review: review),
                const SizedBox(height: AppDimensions.paddingM),
              ],
              const SizedBox(height: AppDimensions.paddingM),
              Center(
                child: SizedBox(
                  width: 160,
                  height: AppDimensions.buttonHeight,
                  child: ElevatedButton(
                    // Planning finished: go to the list where the saved
                    // meeting now appears (clears the planning screens).
                    onPressed: () => Navigator.pushNamedAndRemoveUntil(
                        context, AppRoutes.meetings, (route) => false),
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
                      'Done',
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
        onItemSelected: (item) => _handleNavTap(context, item),
      ),
    );
  }
}

const _sectionTitleStyle = TextStyle(
  fontWeight: FontWeight.w700,
  fontSize: 16,
  color: AppColors.text,
);

/// Simple (non-interactive) card for the winning place.
class _PlaceCard extends StatelessWidget {
  final Meeting meeting;

  const _PlaceCard({required this.meeting});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        border: Border.all(color: const Color(0xFFD9D9D9)),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
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
                      color: AppColors.text),
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
        ],
      ),
    );
  }
}

/// Card for a review of the winning place.
class _ReviewCard extends StatelessWidget {
  final MeetingReview review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        border: Border.all(color: const Color(0xFFD9D9D9)),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
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
                  review.reviewerName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: AppColors.text),
                ),
                const SizedBox(height: AppDimensions.paddingXS),
                Row(
                  children: List.generate(
                    review.rating,
                    (_) => const Icon(Icons.star,
                        color: AppColors.orange, size: 16),
                  ),
                ),
                const SizedBox(height: AppDimensions.paddingXS),
                Text(
                  review.comment,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: AppDimensions.paddingS),
            child: IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                // TODO: Open the review details when that screen exists.
              },
              icon: const Icon(Icons.remove_red_eye_outlined,
                  color: AppColors.primaryBrown, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
