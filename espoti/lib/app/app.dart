import 'package:flutter/material.dart';
import 'routes.dart';
import 'theme.dart';
import '../core/constants/app_strings.dart';

class EspotiApp extends StatelessWidget {
  final String initialRoute;

  const EspotiApp({
    super.key,
    this.initialRoute = AppRoutes.welcome,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: initialRoute,
      routes: AppRoutes.routes,
    );
  }
}
