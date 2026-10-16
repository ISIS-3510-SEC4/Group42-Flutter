import 'package:flutter/material.dart';
import '../../app/routes.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_strings.dart';
import '../../core/widgets/avatar_selector.dart';
import '../../core/widgets/espoti_button.dart';
import '../../core/widgets/espoti_logo.dart';
import '../../core/widgets/espoti_text_field.dart';
import '../../core/widgets/preference_selector.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/user_service.dart';
import '../../models/user.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _confirmEmailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();

  String _avatarUrl = 'https://images.pexels.com/photos/39987037/pexels-photo-39987037.jpeg';
  List<String> _selectedPreferences = ['Walk', 'Eat'];

  String? _firstNameError;
  String? _lastNameError;
  String? _phoneError;
  String? _emailError;
  String? _confirmEmailError;
  String? _passwordError;
  String? _confirmPasswordError;
  String? _preferencesError;
  bool _isLoading = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _confirmEmailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }


  Future<void> _handleGoogleLogin() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final credential = await _authService.signInWithGoogle();
      if (credential == null) return; // user cancelled: stay on login
      await UserService().init();
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
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

  Future<void> _handleRegister() async {
    final email = _emailController.text.trim();
    final isValidDomain = AuthService.isValidEmailDomain(email);

    setState(() {
      _firstNameError = _firstNameController.text.trim().isEmpty
          ? 'Your Name is required'
          : null;
      _lastNameError = _lastNameController.text.trim().isEmpty
          ? 'Last Name is required'
          : null;
      _phoneError = _phoneController.text.trim().isEmpty
          ? 'Phone Number is required'
          : null;

      if (email.isEmpty) {
        _emailError = 'Email is required';
      } else if (!isValidDomain) {
        _emailError = 'Please enter a valid email address (e.g., user@domain.com)';
      } else {
        _emailError = null;
      }

      _confirmEmailError = _confirmEmailController.text.trim() != email
          ? 'Emails do not match'
          : null;

      _passwordError = _passwordController.text.isEmpty
          ? 'Password is required'
          : (_passwordController.text.length < 6
              ? 'Password must be at least 6 characters long'
              : null);

      _confirmPasswordError = _confirmPasswordController.text != _passwordController.text
          ? 'Passwords do not match'
          : null;

      _preferencesError = _selectedPreferences.isEmpty
          ? 'Select at least one preference'
          : null;

      _phoneError = _phoneController.text.trim().isEmpty
          ? 'Phone Number is required'
          : null;
    });

    final isValid = _firstNameError == null &&
        _lastNameError == null &&
        _phoneError == null &&
        _emailError == null &&
        _confirmEmailError == null &&
        _passwordError == null &&
        _confirmPasswordError == null &&
        _preferencesError == null;

    if (!isValid) return;

    setState(() => _isLoading = true);

    try {
      final credential = await _authService.registerWithEmailAndPassword(
        email: email,
        password: _passwordController.text,
      );

      final uid = credential.user?.uid ?? '1234';
      final code = 'ESP${(uid.hashCode % 9000 + 1000).abs()}';
      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();
      final phone = _phoneController.text.trim();
      final newUser = AppUser(
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        name: '$firstName $lastName'.trim(),
        code: code,
        location: 'Bogotá D.C.',
        preferences: _selectedPreferences,
        maxRadiusKm: 10,
        avatarUrl: _avatarUrl,
        email: email,
        description: '',
      );

      await UserService().saveUser(newUser);

      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString();
        // If the error indicates email already exists, highlight it on the email field
        if (errorMsg.contains('ya está registrado')) {
          setState(() => _emailError = errorMsg);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
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
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingXL,
            vertical: AppDimensions.paddingL,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: EspotiLogo(height: AppDimensions.logoSizeMedium)),
              const SizedBox(height: AppDimensions.paddingL),
              Center(
                child: AvatarSelector(
                  currentAvatarUrl: _avatarUrl,
                  onAvatarChanged: (url) => setState(() => _avatarUrl = url),
                ),
              ),
              const SizedBox(height: AppDimensions.paddingM),
              EspotiTextField(
                label: 'Name',
                controller: _firstNameController,
                errorText: _firstNameError,
              ),
              EspotiTextField(
                label: 'Last Name',
                controller: _lastNameController,
                errorText: _lastNameError,
              ),

              EspotiTextField(
                label: 'Phone',
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                errorText: _phoneError,
              ),
              EspotiTextField(
                label: AppStrings.email,
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                errorText: _emailError,
              ),
              EspotiTextField(
                label: AppStrings.confirmEmail,
                controller: _confirmEmailController,
                keyboardType: TextInputType.emailAddress,
                errorText: _confirmEmailError,
              ),
              EspotiTextField(
                label: AppStrings.password,
                controller: _passwordController,
                obscureText: true,
                errorText: _passwordError,
              ),
              EspotiTextField(
                label: AppStrings.confirmPassword,
                controller: _confirmPasswordController,
                obscureText: true,
                errorText: _confirmPasswordError,
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
              const SizedBox(height: AppDimensions.paddingL),
              EspotiButton(
                label: AppStrings.register,
                variant: EspotiButtonVariant.secondary,
                isLoading: _isLoading,
                onPressed: _handleRegister,
              ),
              const SizedBox(height: AppDimensions.paddingL),
              _SocialIconsRow(onGoogleTap: _handleGoogleLogin),
              const SizedBox(height: AppDimensions.paddingL),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    AppStrings.haveAccount,
                    style: TextStyle(color: AppColors.text, fontSize: 13),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pushReplacementNamed(context, AppRoutes.login),
                    child: const Text(
                      AppStrings.login,
                      style: TextStyle(
                        color: AppColors.orange,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.paddingM),
            ],
          ),
        ),
      ),
    );
  }
  

}
class _SocialIconsRow extends StatelessWidget {
  final VoidCallback onGoogleTap;

  const _SocialIconsRow({required this.onGoogleTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Or sign in with: ',
          style: TextStyle(color: AppColors.text, fontSize: 13),
        ),
        _SocialIcon(
          icon: Icons.g_mobiledata,
          color: AppColors.orange,
          onTap: onGoogleTap,
        ),
        const SizedBox(width: AppDimensions.paddingL),
        //const _SocialIcon(icon: Icons.facebook, color: AppColors.primaryBrown),
      ],
    );
  }
}

class _SocialIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _SocialIcon({required this.icon, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {

    return GestureDetector(
      onTap: onTap,
      child: CircleAvatar(
        radius: 20,
        backgroundColor: AppColors.mauve30,
        child: Icon(icon, color: color),
      ),
    );
  }
}
