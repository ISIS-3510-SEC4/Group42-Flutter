import 'package:flutter/material.dart';
import '../../app/routes.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_strings.dart';
import '../../core/widgets/bottom_navigation.dart';
import '../../core/widgets/espoti_button.dart';
import '../../core/widgets/espoti_logo.dart';
import '../../core/widgets/espoti_text_field.dart';

/// "Create a meeting" screen (1). Arrive from the "+" button
/// on the bottom nav. When you press Schedule, it goes to step 2 (vote).
class CreateMeetingPage extends StatefulWidget {
  const CreateMeetingPage({super.key});

  @override
  State<CreateMeetingPage> createState() => _CreateMeetingPageState();
}

class _CreateMeetingPageState extends State<CreateMeetingPage> {
  final _activityController = TextEditingController(text: 'Eat');
  final _dayController = TextEditingController(text: 'Sunday');
  final _timeController = TextEditingController(text: '2:00 pm');

  @override
  void dispose() {
    _activityController.dispose();
    _dayController.dispose();
    _timeController.dispose();
    super.dispose();
  }

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
        break; // TODO:  Add Friends Screen here once it exists
    }
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
              Text(
                AppStrings.createAMeeting,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppDimensions.paddingL),

              // Who will go?
              const Text(
                AppStrings.whoWillGo,
                style: TextStyle(fontSize: 15, color: AppColors.text),
              ),
              const SizedBox(height: AppDimensions.paddingS),
              const _WhoWillGoRow(),
              const SizedBox(height: AppDimensions.paddingL),

              EspotiTextField(
                label: AppStrings.whatWillWeDo,
                controller: _activityController,
              ),
              EspotiTextField(
                label: AppStrings.whatDay,
                controller: _dayController,
              ),
              EspotiTextField(
                label: AppStrings.whatTime,
                controller: _timeController,
              ),

              const SizedBox(height: AppDimensions.paddingS),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    AppStrings.selectYourLocation,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      // TODO: open location picker when it exists (google_maps_flutter / flutter_map)
                    },
                    icon:
                        const Icon(Icons.search, color: AppColors.primaryBrown),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.paddingS),
              const _LocationMapPreview(),
              const SizedBox(height: AppDimensions.paddingXL),

              Center(
                child: EspotiButton(
                  label: AppStrings.schedule,
                  variant: EspotiButtonVariant.secondary,
                  width: 160,
                  onPressed: () => Navigator.pushNamed(
                    context,
                    AppRoutes.voteMeeting,
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

class _WhoWillGoRow extends StatelessWidget {
  const _WhoWillGoRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: AppDimensions.avatarSize + 8,
          height: AppDimensions.avatarSize + 8,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.mauve30,
          ),
          child: const Icon(Icons.person, color: AppColors.primaryBrown),
        ),
        const SizedBox(width: AppDimensions.paddingM),
        GestureDetector(
          onTap: () {
            // TODO: open friends selector when it exists.
          },
          child: const Icon(
            Icons.add_circle,
            color: AppColors.primaryBrown,
            size: 32,
          ),
        ),
      ],
    );
  }
}

/// map placeholder. To be replaced with actual map widget.
/// (google_maps_flutter / flutter_map)
class _LocationMapPreview extends StatelessWidget {
  const _LocationMapPreview();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimensions.radiusL),
      child: Container(
        height: 160,
        width: double.infinity,
        color: AppColors.orange50,
        child: const Icon(
          Icons.map_outlined,
          color: AppColors.primaryBrown,
          size: 40,
        ),
      ),
    );
  }
}
