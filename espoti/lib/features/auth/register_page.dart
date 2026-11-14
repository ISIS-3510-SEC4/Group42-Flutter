import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/routes.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/input_limits.dart';
import '../../core/widgets/avatar_selector.dart';
import '../../core/widgets/espoti_button.dart';
import '../../core/widgets/espoti_logo.dart';
import '../../core/widgets/espoti_text_field.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/user_service.dart';
import '../../core/offline/connectivity_service.dart';
import '../../models/user.dart';

/// Registro con correo y contraseña.
///
/// Solo pide los cinco datos acordados (nombre, apellido, correo, contraseña
/// y teléfono). Avatar, preferencias y las confirmaciones de correo y
/// contraseña se quitaron del formulario; el usuario puede completar avatar y
/// preferencias después desde "Edit Profile". También se puede entrar con
/// Google, que crea el mismo documento users/{uid}.
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
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  String? _firstNameError;
  String? _lastNameError;
  String? _phoneError;
  String? _emailError;
  String? _passwordError;
  bool _isLoading = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Registration is a protected view: Firebase Auth needs the network.
  Future<bool> _ensureOnline() async {
    if (await ConnectivityService.instance.check()) return true;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('No connection. Connect to the internet to sign up.'),
        backgroundColor: Colors.red.shade700,
      ));
    }
    return false;
  }

  Future<void> _handleGoogleLogin() async {
    if (_isLoading) return;
    if (!await _ensureOnline()) return;
    setState(() => _isLoading = true);
    try {
      final credential = await _authService.signInWithGoogle();
      if (credential == null) return; // user cancelled: stay on this screen
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

  /// Valida los cinco campos con los mismos límites que se aplican en la
  /// interfaz ([InputLimits]); el límite superior también se comprueba aquí
  /// por si el texto llega por otra vía (por ejemplo, pegado).
  bool _validate() {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _firstNameError = firstName.isEmpty
          ? 'Name is required'
          : InputLimits.tooLong(firstName, InputLimits.firstName, 'Name');
      _lastNameError = lastName.isEmpty
          ? 'Last name is required'
          : InputLimits.tooLong(lastName, InputLimits.lastName, 'Last name');
      _phoneError = phone.isEmpty
          ? 'Phone number is required'
          : (phone.length < InputLimits.phoneMin ||
                  phone.length > InputLimits.phoneMax)
              ? 'Phone number must have ${InputLimits.phoneMin} to ${InputLimits.phoneMax} digits'
              : null;
      _emailError = email.isEmpty
          ? 'Email is required'
          : InputLimits.tooLong(email, InputLimits.email, 'Email') ??
              (AuthService.isValidEmailDomain(email)
                  ? null
                  : 'Please enter a valid email address (e.g., user@domain.com)');
      _passwordError = password.isEmpty
          ? 'Password is required'
          : password.length < InputLimits.passwordMin
              ? 'Password must be at least ${InputLimits.passwordMin} characters long'
              : InputLimits.tooLong(password, InputLimits.passwordMax, 'Password');
    });

    return _firstNameError == null &&
        _lastNameError == null &&
        _phoneError == null &&
        _emailError == null &&
        _passwordError == null;
  }

  Future<void> _handleRegister() async {
    if (_isLoading || !_validate()) return;
    if (!await _ensureOnline()) return;

    setState(() => _isLoading = true);
    final email = _emailController.text.trim();

    try {
      final credential = await _authService.registerWithEmailAndPassword(
        email: email,
        password: _passwordController.text,
      );

      final uid = credential.user!.uid;
      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();
      // Perfil inicial solo con los datos del formulario. Los campos que ya
      // no se piden quedan vacíos (no se inventan ciudad ni preferencias).
      final newUser = AppUser(
        firstName: firstName,
        lastName: lastName,
        phone: _phoneController.text.trim(),
        name: '$firstName $lastName'.trim(),
        code: 'ESP${(uid.hashCode % 9000 + 1000).abs()}',
        location: '',
        preferences: const [],
        maxRadiusKm: 10,
        avatarUrl: AvatarSelector.presetAvatars.first,
        email: email,
        description: '',
      );

      // El documento users/{uid} se crea a través del outbox (saveUser →
      // SyncQueue.enqueueProfileUpdate), con el uid de Firebase recién creado
      // como id.
      await UserService().saveUser(newUser);

      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString();
        // Si el correo ya existe, el error se marca también en ese campo.
        if (errorMsg.contains('already registered')) {
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
              EspotiTextField(
                label: 'Name',
                controller: _firstNameController,
                errorText: _firstNameError,
                maxLength: InputLimits.firstName,
                textInputAction: TextInputAction.next,
              ),
              EspotiTextField(
                label: 'Last Name',
                controller: _lastNameController,
                errorText: _lastNameError,
                maxLength: InputLimits.lastName,
                textInputAction: TextInputAction.next,
              ),
              EspotiTextField(
                label: AppStrings.email,
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                errorText: _emailError,
                maxLength: InputLimits.email,
                textInputAction: TextInputAction.next,
              ),
              EspotiTextField(
                label: AppStrings.password,
                controller: _passwordController,
                obscureText: true,
                errorText: _passwordError,
                maxLength: InputLimits.passwordMax,
                hintText: 'At least ${InputLimits.passwordMin} characters',
                textInputAction: TextInputAction.next,
              ),
              EspotiTextField(
                label: 'Phone Number',
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                errorText: _phoneError,
                maxLength: InputLimits.phoneMax,
                // Solo dígitos: el límite de longitud es de dígitos reales.
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                hintText: 'Digits only',
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _handleRegister(),
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
              Wrap(
                alignment: WrapAlignment.center,
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
