import 'package:firebase_auth/firebase_auth.dart';
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
import '../../core/offline/connectivity_service.dart';

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

  /// Login is a protected view: Firebase Auth needs the network.
  Future<bool> _ensureOnline() async {
    if (await ConnectivityService.instance.check()) return true;
    _showError('Sin conexión. Conéctate a internet para iniciar sesión.');
    return false;
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    if (!AuthService.isValidEmailDomain(email)) {
      setState(() => _emailError = 'Enter your email to reset the password');
      return;
    }
    if (!await _ensureOnline()) return;
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Te enviamos un correo a $email para restablecer la contraseña.')),
      );
    } on FirebaseAuthException catch (e) {
      _showError(AuthService.getReadableAuthError(e));
    }
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final isValidDomain = AuthService.isValidEmailDomain(email);

    setState(() {
      if (email.isEmpty) {
        _emailError = 'Email is required';
      } else if (!isValidDomain) {
        _emailError = 'Enter an email address with a valid domain (e.g., user@domain.com)';
      } else {
        _emailError = null;
      }
      _passwordError = _passwordController.text.isEmpty ? 'Password is required' : null;
    });

    if (_emailError != null || _passwordError != null) return;
    if (!await _ensureOnline()) return;

    setState(() => _isLoading = true);

    try {
      await _authService.signInWithEmailAndPassword(
        email: email,
        password: _passwordController.text,
      );
      await UserService().init();

      if (mounted) {// Mounted confirma que el widget esta activo
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
    if (!await _ensureOnline()) return;
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
            mainAxisAlignment: MainAxisAlignment.center,
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
              Center(
                child: TextButton(
                  onPressed: _isLoading ? null : _handleForgotPassword,
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
