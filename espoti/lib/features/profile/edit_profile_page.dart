import 'package:flutter/material.dart';
import '../../app/routes.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_strings.dart';
import '../../core/widgets/avatar_selector.dart';
import '../../core/widgets/bottom_navigation.dart';
import '../../core/widgets/espoti_button.dart';
import '../../core/widgets/espoti_logo.dart';
import '../../core/widgets/espoti_text_field.dart';
import '../../core/widgets/preference_selector.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/user_service.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _descriptionController;

  late String _avatarUrl;
  late List<String> _selectedPreferences;

  String? _firstNameError;
  String? _lastNameError;
  String? _emailError;
  String? _preferencesError;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = UserService().currentUser;

    _firstNameController = TextEditingController(text: user.firstName.isNotEmpty ? user.firstName : user.name);
    _lastNameController = TextEditingController(text: user.lastName);
    _emailController = TextEditingController(text: user.email);
    _descriptionController = TextEditingController(text: user.description);

    _avatarUrl = user.avatarUrl.isNotEmpty ? user.avatarUrl : 'https://i.pravatar.cc/200?img=13';
    _selectedPreferences = List<String>.from(user.preferences);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
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
        Navigator.pushReplacementNamed(context, AppRoutes.friends);
        break;
    }
  }

  Future<void> _handleSave() async {
    final email = _emailController.text.trim();
    final isValidDomain = email.isEmpty || AuthService.isValidEmailDomain(email);

    setState(() {
      _firstNameError = _firstNameController.text.trim().isEmpty ? 'El nombre es obligatorio' : null;
      _lastNameError = _lastNameController.text.trim().isEmpty ? 'El apellido es obligatorio' : null;
      _emailError = !isValidDomain ? 'Ingresa un correo con un dominio válido (ej. usuario@dominio.com)' : null;
      _preferencesError = _selectedPreferences.isEmpty ? 'Selecciona al menos una preferencia' : null;
    });

    final isValid = _firstNameError == null &&
        _lastNameError == null &&
        _emailError == null &&
        _preferencesError == null;

    if (!isValid) return;

    setState(() => _isLoading = true);

    try {
      final currentUser = UserService().currentUser;
      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();

      final updatedUser = currentUser.copyWith(
        firstName: firstName,
        lastName: lastName,
        name: '$firstName $lastName'.trim(),
        email: email,
        avatarUrl: _avatarUrl,
        preferences: _selectedPreferences,
        description: _descriptionController.text.trim(),
      );

      await UserService().saveUser(updatedUser);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil actualizado correctamente'),
            backgroundColor: AppColors.orange,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
              const SizedBox(height: AppDimensions.paddingL),
              Text(
                AppStrings.editProfileTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppDimensions.paddingL),
              Center(
                child: AvatarSelector(
                  currentAvatarUrl: _avatarUrl,
                  onAvatarChanged: (url) => setState(() => _avatarUrl = url),
                ),
              ),
              const SizedBox(height: AppDimensions.paddingL),
              EspotiTextField(
                label: 'Nombre',
                controller: _firstNameController,
                errorText: _firstNameError,
              ),
              EspotiTextField(
                label: 'Apellido',
                controller: _lastNameController,
                errorText: _lastNameError,
              ),
              EspotiTextField(
                label: AppStrings.email,
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                errorText: _emailError,
              ),
              const SizedBox(height: AppDimensions.paddingS),
              PreferenceSelector(
                selectedPreferences: _selectedPreferences,
                onPreferencesChanged: (prefs) {
                  setState(() {
                    _selectedPreferences = prefs;
                    _preferencesError = null;
                  });
                },
                errorText: _preferencesError,
              ),
              const SizedBox(height: AppDimensions.paddingM),
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
                  isLoading: _isLoading,
                  onPressed: _handleSave,
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
