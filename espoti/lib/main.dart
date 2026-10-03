import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'app/app.dart';

import 'app/routes.dart';
import 'core/services/auth_service.dart';
import 'core/services/user_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await UserService().init();

  final initialRoute =
      AuthService().isAuthenticated ? AppRoutes.home : AppRoutes.welcome;

  runApp(EspotiApp(initialRoute: initialRoute));
}
