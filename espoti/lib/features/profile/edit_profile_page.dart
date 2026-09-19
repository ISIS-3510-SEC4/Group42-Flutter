import 'package:flutter/material.dart';
import '../../app/routes.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_strings.dart';
import '../../core/widgets/bottom_navigation.dart';
import '../../core/widgets/espoti_button.dart';
import '../../core/widgets/espoti_logo.dart';
import '../../core/widgets/espoti_text_field.dart';
import '../../models/user.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final TextEditingController _usernameController;
  late final TextEditingController _emailController;
  late final TextEditingController _preferencesController;
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    const user = mockUser;
    _usernameController = TextEditingController(text: user.name);
    _emailController = TextEditingController(text: user.email);
    _preferencesController =
        TextEditingController(text: user.preferences.join(', '));
    _descriptionController = TextEditingController(text: user.description);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _preferencesController.dispose();
    _descriptionController.dispose();
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
        Navigator.pushNamed(context, AppRoutes.createMeeting);
        break;
      case EspotiNavItem.friends:
        break; // TODO: Friends screen does not exist yet.
    }
  }

  void _handleSave() {
    // TODO: Persist changes when the backend is available.
    Navigator.pop(context);
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
                AppStrings.editProfileTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppDimensions.paddingL),
              Center(child: _AvatarPicker()),
              const SizedBox(height: AppDimensions.paddingL),
              EspotiTextField(
                label: AppStrings.username,
                controller: _usernameController,
              ),
              EspotiTextField(
                label: AppStrings.email,
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
              ),
              EspotiTextField(
                label: AppStrings.preferences,
                controller: _preferencesController,
              ),
              EspotiTextField(
                label: AppStrings.description,
                controller: _descriptionController,
                hintText: AppStrings.writeSomethingFun,
              ),
              const SizedBox(height: AppDimensions.paddingL),
              Center(
                child: EspotiButton(
                  label: AppStrings.save,
                  variant: EspotiButtonVariant.secondary,
                  width: 160,
                  onPressed: _handleSave,
                ),
              ),
              const SizedBox(height: AppDimensions.paddingS),
              Center(
                child: GestureDetector(
                  onTap: () {
                    // TODO: Open the password change flow when available.
                  },
                  child: const Text(
                    AppStrings.changePassword,
                    style: TextStyle(color: AppColors.orange, fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.paddingXL),
            ],
          ),
        ),
      ),
      bottomNavigationBar: EspotiBottomNavigation(
        currentItem: EspotiNavItem.profile,
        onItemSelected: _handleNavTap,
      ),
    );
  }
}

class _AvatarPicker extends StatelessWidget {
  const _AvatarPicker();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // TODO: Open the photo picker when that integration is available.
      },
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: AppColors.mauve30,
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        ),
        child:
            const Icon(Icons.person, color: AppColors.primaryBrown, size: 56),
      ),
    );
  }
}
