import 'package:flutter/material.dart';
import '../../app/routes.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_strings.dart';
import '../../core/widgets/espoti_button.dart';
import '../../core/widgets/espoti_logo.dart';
import '../../core/widgets/espoti_text_field.dart';

import '../../core/services/auth_service.dart';

import '../../core/services/user_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  String? _emailError;
  String? _passwordError;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final isValidDomain = AuthService.isValidEmailDomain(email);

    setState(() {
      if (email.isEmpty) {
        _emailError = 'Email is required';
      } else if (!isValidDomain) {
        _emailError = 'Ingresa un correo con un dominio válido (ej. usuario@dominio.com)';
      } else {
        _emailError = null;
      }
      _passwordError = _passwordController.text.isEmpty ? 'Password is required' : null;
    });

    if (_emailError != null || _passwordError != null) return;

    setState(() => _isLoading = true);

    try {
      await _authService.signInWithEmailAndPassword(
        email: email,
        password: _passwordController.text,
      );
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
              const SizedBox(height: AppDimensions.paddingXL),
              EspotiTextField(
                label: AppStrings.email,
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                errorText: _emailError,
              ),
              EspotiTextField(
                label: AppStrings.password,
                controller: _passwordController,
                obscureText: true,
                errorText: _passwordError,
              ),
              const SizedBox(height: AppDimensions.paddingM),
              EspotiButton(
                label: AppStrings.login,
                variant: EspotiButtonVariant.secondary,
                isLoading: _isLoading,
                onPressed: _handleLogin,
              ),
              const SizedBox(height: AppDimensions.paddingL),
              _SocialIconsRow(onGoogleTap: _handleGoogleLogin),
              const SizedBox(height: AppDimensions.paddingL),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    AppStrings.noAccount,
                    style: TextStyle(color: AppColors.text, fontSize: 13),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pushReplacementNamed(context, AppRoutes.register),
                    child: const Text(
                      AppStrings.signUp,
                      style: TextStyle(
                        color: AppColors.orange,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.paddingS),
              // "Forgot Password?" intentionally does not navigate anywhere
              Center(
                child: TextButton(
                  onPressed: null,
                  child: Text(
                    AppStrings.forgotPassword,
                    style: TextStyle(color: AppColors.orange.withValues(alpha: 0.8)),
                  ),
                ),
              ),
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
        _SocialIcon(
          icon: Icons.g_mobiledata,
          color: AppColors.orange,
          onTap: onGoogleTap,
        ),
        const SizedBox(width: AppDimensions.paddingL),
        const _SocialIcon(icon: Icons.facebook, color: AppColors.primaryBrown),
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
    // Decorative unless [onTap] is provided (Google login).
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
