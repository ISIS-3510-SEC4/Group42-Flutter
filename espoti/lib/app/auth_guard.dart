import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/services/auth_service.dart';

/// Route guard: [child] is only built while there is a Firebase session.
///
/// It observes [AuthService.authStateChanges], so it also reacts when the
/// session ends while the screen is open (sign-out, revoked token): the user
/// is sent to [redirectRoute] and the navigation stack is cleared.
class AuthGuard extends StatefulWidget {
  final Widget child;
  final String redirectRoute;

  const AuthGuard({super.key, required this.child, required this.redirectRoute});

  @override
  State<AuthGuard> createState() => _AuthGuardState();
}

class _AuthGuardState extends State<AuthGuard> {
  bool _redirecting = false;

  // _redirecting evita navegar varias veces si build se ejecuta varias veces.
  // addPostFrameCallback: no se puede navegar en medio de un build.
  void _redirect() {
    if (_redirecting) return;
    _redirecting = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context)
          .pushNamedAndRemoveUntil(widget.redirectRoute, (route) => false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    // Observer con Stream: StreamBuilder se suscribe a authStateChanges de
    // FirebaseAuth. initialData evita un frame de carga si ya hay usuario.
    // Cuando el stream emite null (signOut o token revocado) se redirige y se
    // limpia la pila.
    return StreamBuilder<User?>(
      stream: auth.authStateChanges,
      initialData: auth.currentUser,
      builder: (context, snapshot) {
        if (snapshot.data == null) {
          _redirect();
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
                child: CircularProgressIndicator(color: AppColors.primaryBrown)),
          );
        }
        return widget.child;
      },
    );
  }
}
