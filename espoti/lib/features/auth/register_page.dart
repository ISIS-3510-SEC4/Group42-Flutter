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
  final _emailController = TextEditingController();
  final _confirmEmailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();

  String _avatarUrl = 'https://i.pravatar.cc/200?img=13';
  List<String> _selectedPreferences = ['Walk', 'Eat'];

  String? _firstNameError;
  String? _lastNameError;
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
    _emailController.dispose();
    _confirmEmailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    final email = _emailController.text.trim();
    final isValidDomain = AuthService.isValidEmailDomain(email);

    setState(() {
      _firstNameError = _firstNameController.text.trim().isEmpty
          ? 'El nombre es obligatorio'
          : null;
      _lastNameError = _lastNameController.text.trim().isEmpty
          ? 'El apellido es obligatorio'
          : null;

      if (email.isEmpty) {
        _emailError = 'El correo es obligatorio';
      } else if (!isValidDomain) {
        _emailError = 'Ingresa un correo con un dominio válido (ej. usuario@dominio.com)';
      } else {
        _emailError = null;
      }

      _confirmEmailError = _confirmEmailController.text.trim() != email
          ? 'Los correos no coinciden'
          : null;

      _passwordError = _passwordController.text.isEmpty
          ? 'La contraseña es obligatoria'
          : (_passwordController.text.length < 6
              ? 'La contraseña debe tener al menos 6 caracteres'
              : null);

      _confirmPasswordError = _confirmPasswordController.text != _passwordController.text
          ? 'Las contraseñas no coinciden'
          : null;

      _preferencesError = _selectedPreferences.isEmpty
          ? 'Selecciona al menos una preferencia'
          : null;
    });

    final isValid = _firstNameError == null &&
        _lastNameError == null &&
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

      final newUser = AppUser(
        firstName: firstName,
        lastName: lastName,
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
